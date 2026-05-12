module Api
  module V1
    class TemplatesController < BaseController
      before_action :set_template, only: %i[show update destroy preview]

      def index
        scope = current_account.email_templates.order(updated_at: :desc)
        scope = scope.where(status: params[:status]) if params[:status].present?
        render json: scope.map { |t| serialize(t) }
      end

      def show
        render json: serialize(@template)
      end

      def create
        template = current_account.email_templates.new(template_params)
        template.save!
        render json: serialize(template), status: :created
      end

      def update
        @template.update!(template_params)
        render json: serialize(@template)
      end

      def destroy
        # Prefer archive to preserve campaign history. Set ?hard=true to permanently remove.
        if ActiveModel::Type::Boolean.new.cast(params[:hard])
          @template.destroy!
          head :no_content
        else
          @template.archive!
          render json: serialize(@template)
        end
      end

      def preview
        contact = lookup_contact(params[:contact_id]) || sample_contact
        campaign = lookup_campaign(params[:campaign_id])
        result = TemplateRenderer.render(template: @template, contact: contact, campaign: campaign)

        if result.success?
          render json: { subject: result.subject, html: result.html, plain: result.plain }
        else
          render json: { error: "render_failed", details: result.errors }, status: :unprocessable_entity
        end
      end

      private

      def set_template
        @template = EmailTemplate.find_by_id_or_slug!(current_account, params[:id])
      end

      def template_params
        params.permit(:name, :slug, :subject_template, :html_body, :plain_body, :status, default_variables: {})
      end

      def lookup_contact(id)
        return nil if id.blank?

        current_account.contacts.find_by(id: id)
      end

      def lookup_campaign(id)
        return nil if id.blank?

        current_account.campaigns.find_by(id: id)
      end

      def sample_contact
        Contact.new(
          account: current_account,
          email: "sample@example.com",
          first_name: "Sample",
          last_name: "Contact",
          metadata: { "company" => "Acme Inc." }
        )
      end

      def serialize(template)
        {
          id: template.id,
          name: template.name,
          slug: template.slug,
          subject_template: template.subject_template,
          html_body: template.html_body,
          plain_body: template.plain_body,
          default_variables: template.default_variables,
          status: template.status,
          created_at: template.created_at,
          updated_at: template.updated_at
        }
      end
    end
  end
end
