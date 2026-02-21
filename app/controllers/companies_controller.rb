class CompaniesController < ApplicationController
  before_action :set_company, only: %i[ show ]

  # GET /companies/new
  def new
    @company = Company.new
  end

  # POST /companies
  def create
    @company = current_user.owned_companies.build(company_params)
    if @company.save
      # Add owner as supervisor attendant
      @company.company_attendants.create!(
        user:           current_user,
        role_name:      "Admin",
        attendant_type: :human,
        is_supervisor:  true,
        status:         :available
      )
      redirect_to company_dashboard_path, notice: "Empresa criada com sucesso!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /companies/:id  (public profile)
  def show
  end

  private

  def set_company
    @company = Company.find(params[:id])
  end

  def company_params
    params.require(:company).permit(:name, :nickname, :description, :bio, :logo)
  end
end
