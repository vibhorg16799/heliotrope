# frozen_string_literal: true

module Hyrax
  # view-model for the admin menu
  class MenuPresenter
    def initialize(view_context)
      @view_context = view_context
    end

    attr_reader :view_context

    delegate :controller, :controller_name, :action_name, :content_tag,
             :current_page?, :link_to, :can?, to: :view_context

    # Returns true if the current controller happens to be one of the controllers that deals
    # with settings.  This is used to keep the parent section on the sidebar open.
    def settings_section?
      %w[appearances content_blocks features pages].include?(controller_name)
    end

    # @param options [Hash, String] a hash or string representing the path. Hash is prefered as it
    #                              allows us to workaround https://github.com/rails/rails/issues/28253
    # @param also_active_for [Hash, String] a hash or string with alternative paths that should be 'active'
    def nav_link(options, also_active_for: nil, **link_html_options, &block)
      active_urls = [options, also_active_for].compact
      list_options = active_urls.any? { |url| current_page?(url) } ? { class: 'active' } : {}
      content_tag(:li, list_options) do
        link_to(options, link_html_options, &block)
      end
    end

    # @return [Boolean] true if the current controller happens to be one of the controllers that deals
    # with user activity  This is used to keep the parent section on the sidebar open.
    def user_activity_section?
      # we're using a case here because we need to differentiate UsersControllers
      # in different namespaces (Hyrax & Admin)
      case controller
      when Hyrax::UsersController, Hyrax::NotificationsController, Hyrax::TransfersController
        true
      else
        false
      end
    end

    # @return [Boolean] true if the current controller happens to be one of the controllers that deals
    # with reports. This is used to keep the parent section on the sidebar open.
    def report_section?
      # we're using a case here because we need to differentiate UsersControllers
      # in different namespaces (Hyrax & Admin)
      case controller
      when Hyrax::Admin::StatsController
        true
      else
        false
      end
    end

    # Draw a collaspable menu section. The passed block should contain <li> items.
    def collapsable_section(text, id:, icon_class:, open:, &block)
      CollapsableSectionPresenter.new(view_context: view_context,
                                      text: text,
                                      id: id,
                                      icon_class: icon_class,
                                      open: open).render(&block)
    end

    # @return [Boolean] will the configuration section be displayed to the user
    def show_configuration?
      can?(:update, :appearance) ||
        can?(:manage, Sipity::WorkflowResponsibility) ||
        can?(:manage, Hyrax::Feature)
    end
  end
end
