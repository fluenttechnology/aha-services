class JiraVersionResource < JiraResource
  def find_by_id(id)
    prepare_request
    response = http_get "#{api_url}/version/#{id}"
    found_resource(response)
  end

  def find_by_name(name)
    prepare_request
    response = http_get "#{api_url}/project/#{@service.data.project}/versions"
    process_response(response, 200) do |versions|
      return versions.find { |version| version.name.mb_chars.downcase == name.mb_chars.downcase }
    end
  end

  def create(new_version)
    prepare_request
    response = http_post "#{api_url}/version",
                         new_version.merge(project: @service.data.project).to_json
    process_response(response, 201) do |version|
      return version
    end
  end

  def update(id, updated_version)
    prepare_request
    response = http_put "#{api_url}/version/#{id}",
      updated_version.merge(id: id).to_json
    process_response(response, 200) do |version|
      return version
    end
  end
end
