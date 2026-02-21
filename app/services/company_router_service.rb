class CompanyRouterService
  attr_reader :company, :assignment

  def initialize(company, assignment)
    @company    = company
    @assignment = assignment
  end

  # Called when a customer selects a department from the menu.
  # department_id: the "id" field from menu_config["departments"]
  def route(department_id)
    dept = find_department(department_id)
    return false unless dept

    assignment.update!(selected_department: dept["label"] || dept[:label])

    attendant = find_available_attendant(dept["role_name"] || dept[:role_name])

    if attendant
      assignment.assign_to!(attendant)
      send_assigned_message(attendant)
      true
    else
      queue_and_notify(dept)
      false
    end
  end

  # Send the initial interactive menu to a new customer
  def send_menu_to(customer_user)
    conversation = Conversation.find_or_create_company_direct(company, customer_user)

    # Build the message content
    list_sections = [{
      "title" => "Departamentos",
      "rows"  => company.departments.map do |dept|
        {
          "id"    => dept["id"] || dept[:id],
          "title" => dept["label"] || dept[:label],
          "desc"  => dept["role_name"] || dept[:role_name]
        }
      end
    }]

    msg = conversation.messages.create!(
      sender:       company.owner,
      content:      company.greeting,
      message_type: :company_menu
    )

    # Create or update the assignment for this conversation
    assignment = ConversationAssignment.find_or_create_by!(
      conversation: conversation,
      company:      company
    ) do |a|
      a.status = :pending
    end

    # Store menu metadata for routing later — attach to message metadata
    msg.update_column(:metadata, {
      "company_menu" => true,
      "company_id"   => company.id,
      "assignment_id"=> assignment.id,
      "list_sections"=> list_sections,
      "list_header"  => { "text" => "Escolha um departamento" }
    })

    [conversation, assignment, msg]
  end

  private

  def find_department(department_id)
    company.departments.find { |d| (d["id"] || d[:id]).to_s == department_id.to_s }
  end

  def find_available_attendant(role_name)
    return nil if role_name.blank?
    company.company_attendants
           .status_available
           .where(role_name: role_name)
           .order(Arel.sql("RANDOM()"))
           .first
  end

  def send_assigned_message(attendant)
    assignment.conversation.messages.create!(
      sender:       attendant.user,
      content:      "Olá! Meu nome é #{attendant.user.display_name} e vou te atender no departamento #{assignment.selected_department}. Como posso ajudar?",
      message_type: :text
    )
  end

  def queue_and_notify(dept)
    assignment.update!(status: :queued)

    # Notify customer that all attendants are busy
    assignment.conversation.messages.create!(
      sender:       company.owner,
      content:      "Todos os atendentes do departamento *#{dept['label']}* estão ocupados no momento. Você está na fila e será atendido em breve.",
      message_type: :text
    )

    # Notify supervisors via CompanyChannel
    CompanyChannel.broadcast_to(company, {
      type:            "new_queued_assignment",
      assignment_id:   assignment.id,
      department:      dept["label"],
      conversation_id: assignment.conversation_id
    })
  end
end
