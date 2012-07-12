class DefaultController < ApplicationController
  before_filter :require_user, :only => :service_info

  def info
    info = {
      :name => 'vcap',
      :build => 2222,
      :support =>  AppConfig[:support_address],
      :version =>  CloudController.version,
      :description =>  AppConfig[:description],
      :allow_debug =>  AppConfig[:allow_debug]
    }
    if uaa_enabled?
      info[:authorization_endpoint] = AppConfig[:uaa][:url]
    end
    # If there is a logged in user, give out additional information
    if user
      info[:user]       = user.email
      info[:limits]     = user.account_capacity
      info[:usage]      = user.account_usage
      info[:frameworks] = StagingPlugin.manifests_info
    end
    render :json => info
  end

  def runtime_info
    render :json => AppConfig[:runtimes]
  end

  def service_info
    svcs = Service.active_services.select {|svc| svc.visible_to_user?(user)}
    CloudController.logger.debug("Global service listing found #{svcs.length} services.")

    ret = {}
    svcs.each do |svc|
      svc_type = svc.synthesize_service_type
      ret[svc_type] ||= {}
      ret[svc_type][svc.name] ||= {}

      versions = svc.supported_versions
      # backward compatible, svc.version will be removed.
      versions = [ svc.version ] if versions.empty?

      version_aliases = svc.version_aliases
      versions.each do |version|
        svc_desc = svc.as_legacy(user)
        svc_desc[:version] = version
        version_alias = svc.version_to_alias(version)

        # Until we have a way to dis-ambiguate between client requests coming in from old clients vs. version aware client,
        # send ONLY the current versions out.
        skip_non_current_versions_for_old_clients = !(version_alias == "current" || version_alias.to_s.empty?)

        # CloudController.logger.debug("Service: #{svc.name}, Version: #{version} (#{version_alias}), skip for old clients: #{skip_non_current_versions_for_old_clients}")

        # COMMENT the line below for multi-version testing
        next if skip_non_current_versions_for_old_clients

        svc_desc[:alias] = version_alias if version_alias
        ret[svc_type][svc.name][version] ||= {}
        ret[svc_type][svc.name][version] = svc_desc
      end
    end

    render :json => ret
  end

  def index
    if AppConfig[:index_page]
      redirect_to AppConfig[:index_page]
    else
      render :text => "Welcome to VMware's Cloud Application Platform\n"
    end
  end

  def not_implemented
    $stderr.puts "\nNOT IMPLEMENTED: #{request.fullpath} #{request.body.read}"
    render :json => {"error" => "Not yet implemented"}
  end

  # be fairly quiet on bad routes
  def route_not_found
    render :nothing => true, :status => :not_found
  end

end
