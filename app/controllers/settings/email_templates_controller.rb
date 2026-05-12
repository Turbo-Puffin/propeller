module Settings
  class EmailTemplatesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_template, only: %i[show edit update destroy duplicate preview archive unarchive]

    def index
      scope = current_account.email_templates.order(updated_at: :desc)
      @status_filter = params[:status].presence
      scope = scope.where(status: @status_filter) if @status_filter
      @templates = scope
    end

    def show
    end

    def new
      @template = current_account.email_templates.build(status: "active", default_variables: {})
    end

    def create
      @template = current_account.email_templates.build(template_params)

      if @template.save
        redirect_to settings_email_template_path(@template), notice: "Template created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @template.update(template_params)
        redirect_to settings_email_template_path(@template), notice: "Template updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @template.destroy
      redirect_to settings_email_templates_path, notice: "Template deleted."
    end

    def archive
      @template.archive!
      redirect_to settings_email_template_path(@template), notice: "Template archived."
    end

    def unarchive
      @template.unarchive!
      redirect_to settings_email_template_path(@template), notice: "Template restored."
    end

    def duplicate
      copy = current_account.email_templates.build(
        name: "#{@template.name} (copy)",
        slug: next_copy_slug(@template.slug),
        subject_template: @template.subject_template,
        html_body: @template.html_body,
        plain_body: @template.plain_body,
        default_variables: @template.default_variables,
        status: "active"
      )
      copy.save!
      redirect_to settings_email_template_path(copy), notice: "Template duplicated."
    end

    def preview
      contact = lookup_contact(params[:contact_id]) || sample_contact
      @preview = TemplateRenderer.render(template: @template, contact: contact)
      @sample_contact = contact
      render :preview
    end

    private

    def current_account
      current_user.account
    end

    def set_template
      @template = EmailTemplate.find_by_id_or_slug!(current_account, params[:id])
    end

    def template_params
      permitted = params.require(:email_template).permit(:name, :slug, :subject_template, :html_body, :plain_body, :status, :default_variables_json)

      raw = permitted.delete(:default_variables_json)
      if raw.present?
        begin
          parsed = JSON.parse(raw)
          permitted[:default_variables] = parsed.is_a?(Hash) ? parsed : {}
        rescue JSON::ParserError
          permitted[:default_variables] = {}
        end
      end

      permitted
    end

    def lookup_contact(id)
      return nil if id.blank?

      current_account.contacts.find_by(id: id)
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

    def next_copy_slug(slug)
      base = "#{slug}-copy"
      candidate = base
      i = 1
      while current_account.email_templates.exists?(slug: candidate)
        i += 1
        candidate = "#{base}-#{i}"
      end
      candidate
    end
  end
end
