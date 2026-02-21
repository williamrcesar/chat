module Marketing
  class CampaignsController < BaseController
    before_action :set_campaign, only: %i[show launch pause deliveries]

    def index
      @campaigns = current_user.marketing_campaigns
                               .includes(:marketing_template)
                               .order(created_at: :desc)
    end

    def show
      @deliveries_by_status = @campaign.campaign_deliveries
                                       .includes(:recipient_user)
                                       .group_by(&:status)
    end

    def new
      @campaign  = MarketingCampaign.new
      @templates = current_user.marketing_templates.order(:name)
    end

    def create
      @campaign = current_user.marketing_campaigns.build(campaign_params)
      if @campaign.save
        redirect_to marketing_campaign_path(@campaign), notice: "Campanha criada. Clique em Enviar para iniciar."
      else
        @templates = current_user.marketing_templates.order(:name)
        render :new, status: :unprocessable_entity
      end
    end

    # POST /marketing/campaigns/:id/launch
    def launch
      if @campaign.status_draft? || @campaign.status_paused?
        @campaign.launch!
        redirect_to marketing_campaign_path(@campaign), notice: "Campanha iniciada!"
      else
        redirect_to marketing_campaign_path(@campaign), alert: "Campanha não pode ser iniciada nesse estado."
      end
    end

    # POST /marketing/campaigns/:id/pause
    def pause
      if @campaign.status_running?
        @campaign.pause!
        redirect_to marketing_campaign_path(@campaign), notice: "Campanha pausada."
      else
        redirect_to marketing_campaign_path(@campaign), alert: "Campanha não está em execução."
      end
    end

    private

    def set_campaign
      @campaign = current_user.marketing_campaigns.find(params[:id])
    end

    def campaign_params
      params.require(:marketing_campaign).permit(
        :name, :marketing_template_id, :daily_limit, :scheduled_at,
        recipient_identifiers: []
      )
    end
  end
end
