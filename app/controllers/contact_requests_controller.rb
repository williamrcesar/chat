class ContactRequestsController < ApplicationController
  before_action :set_request, only: %i[accept block]

  # GET /contact_requests
  def index
    @pending_requests = current_user.received_contact_requests
                                    .status_pending
                                    .includes(:sender)
                                    .order(created_at: :desc)
  end

  # POST /contact_requests  (called from new-conversation flow)
  def create
    # ── Company nickname check: if target is a company, route directly to company menu ──
    company = find_target_company
    if company
      router  = CompanyRouterService.new(company, nil)
      conversation, assignment, _msg = router.send_menu_to(current_user)
      redirect_to conversation_path(conversation), notice: "Bem-vindo a #{company.name}! Selecione um departamento para ser atendido."
      return
    end

    target = find_target_user
    unless target
      redirect_to root_path, alert: "Usuário ou empresa não encontrado com esse nickname ou telefone."
      return
    end

    if target == current_user
      redirect_to root_path, alert: "Você não pode enviar uma solicitação para si mesmo."
      return
    end

    # If already contacts, just open the conversation
    if current_user.contact_with?(target)
      conversation = Conversation.find_or_create_direct(current_user, target)
      redirect_to conversation_path(conversation)
      return
    end

    # Check if blocked
    blocked = ContactRequest.find_by(sender: target, receiver: current_user, status: :blocked)
    if blocked
      redirect_to root_path, alert: "Não foi possível enviar a solicitação."
      return
    end

    existing = ContactRequest.find_by(sender: current_user, receiver: target)
    if existing
      redirect_to root_path, notice: "Solicitação já enviada, aguardando aprovação de @#{target.nickname || target.display_name}."
      return
    end

    preview_type, preview_text = build_preview(params[:message_content], params[:message_type])

    req = ContactRequest.create!(
      sender:       current_user,
      receiver:     target,
      preview_type: preview_type,
      preview_text: preview_text
    )

    redirect_to root_path, notice: "Solicitação enviada para @#{target.nickname || target.display_name}."
  end

  # PATCH /contact_requests/:id/accept
  def accept
    unless @request.status_pending?
      redirect_to contact_requests_path, alert: "Esta solicitação não está mais pendente."
      return
    end

    conversation = @request.accept!
    redirect_to conversation_path(conversation), notice: "Solicitação aceita! Você pode conversar agora."
  end

  # PATCH /contact_requests/:id/block
  def block
    @request.block!
    redirect_to contact_requests_path, notice: "Usuário bloqueado."
  end

  private

  def set_request
    @request = current_user.received_contact_requests.find(params[:id])
  end

  def find_target_company
    q = params[:nickname].to_s.strip.gsub(/\A@/, "")
    return nil if q.blank?
    Company.find_by_nickname(q)
  end

  def find_target_user
    q = params[:nickname].to_s.strip.gsub(/\A@/, "")
    phone = params[:phone].to_s.strip

    if q.present?
      User.find_by("lower(nickname) = ?", q.downcase) ||
        User.find_by("lower(display_name) = ?", q.downcase)
    elsif phone.present?
      User.find_by(phone: phone)
    end
  end

  def build_preview(content, type)
    case type.to_s
    when "image"    then [ "image", nil ]
    when "template" then [ "template", content.to_s.truncate(200) ]
    else                 [ "text",  content.to_s.truncate(80) ]
    end
  end
end
