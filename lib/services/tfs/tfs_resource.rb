class TFSResource < GenericResource

  API_VERSION = "1.0"

  def faraday_builder b
    b.basic_auth(@service.data.user_name, @service.data.user_password)
    b.request(:tfs_ntlm, @service.data.user_name, @service.data.user_password)
  end

  def self.default_http_options
    super
    @@default_http_options[:headers]["Content-Type"] = "application/json"
    @@default_http_options
  end

  def process_response(response, *success_codes, &block)
    success_codes = [200] if success_codes == []
    if success_codes.include?(response.status)
      if block_given?
        yield hashie_or_array_of_hashies(response.body)
      else
        return hashie_or_array_of_hashies(response.body)
      end
    elsif response.status == 302
      raise_config_error "You must use the alternate credentials rather than your login credentials."
    elsif response.status == 404
      raise AhaService::RemoteError, "Remote resource was not found."
    elsif response.status == 400
      raise AhaService::RemoteError, "The request was not valid."
    elsif [403, 401].include?(response.status)
      raise_config_error "Credentials are invalid or have insufficent rights."
    else
      raise AhaService::RemoteError, "Unhandled error: STATUS=#{response.status} BODY=#{response.body}"
    end
  end
  
  def create_attachments(workitem, aha_attachments)
    existing_files = workitem.relations.select{|relation| relation.rel == "AttachedFile"}.map{|relation| relation.attributes.name} rescue []
    aha_attachments.each do |aha_attachment|
      next if existing_files.include?(aha_attachment.file_name)
      new_attachment = attachment_resource.create aha_attachment
      workitem_resource.add_attachment workitem, new_attachment, aha_attachment.file_size
    end
  rescue AhaService::RemoteError => e
    logger.error e.message
  end

protected
  def description_or_default(body)
    if body.present?
      body
    else
      "<p></p>"
    end
  end
 
  def mstfs_url path
    joiner = (path =~ /\?/) ? "&" : "?"
    "#{url_prefix}/_apis/#{path}#{joiner}api-version="+self.class::API_VERSION
  end

  def mstfs_project_url project, path
    joiner = (path =~ /\?/) ? "&" : "?"
    "#{url_prefix}/#{project}/_apis/#{path}#{joiner}api-version="+self.class::API_VERSION
  end
  
  def url_prefix
    if @service.data.account_name =~ /https?:/
      @service.data.account_name
    else
      "https://#{@service.data.account_name}.visualstudio.com/defaultcollection"
    end
  end
  
end


class TfsNtlm < Faraday::Middleware

  def initialize(app, username, password)
    @app = app
    @username = username
    @password = password
  end

  def call(env)
    response = handshake(env)
    return response unless response.status == 401

    env[:request_headers]['Authorization'] = header(response)
    @app.call(env)
  end
    
  def handshake(env)
    env_without_body = env.dup
    #env_without_body.delete(:body) #unless @opts[:keep_body_on_handshake]
    env[:request_headers]['Authorization'] = 'NTLM ' + NTLM.negotiate.to_base64
    @app.call(env_without_body)
  end
  
  def header(response)
    challenge = response.headers['www-authenticate'][/NTLM (.*)/, 1].unpack('m').first rescue nil
    'NTLM ' + NTLM.authenticate(challenge, @username, nil, @password).to_base64
  end
end

Faraday::Request.register_middleware :tfs_ntlm => lambda { TfsNtlm }
