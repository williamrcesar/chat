class CompanyChannel < ApplicationCable::Channel
  def subscribed
    company = find_authorized_company
    if company
      @company = company
      stream_for company
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  # Attendant updates their own status from the dashboard
  def update_status(data)
    return unless @company

    attendant = @company.company_attendants.find_by(user: current_user)
    return unless attendant

    new_status = data["status"].to_s
    attendant.set_status!(new_status) if CompanyAttendant.statuses.key?(new_status)
  end

  private

  def find_authorized_company
    company_id = params[:company_id]
    return nil unless company_id

    company = Company.find_by(id: company_id)
    return nil unless company
    return nil unless company.member?(current_user)

    company
  end
end
