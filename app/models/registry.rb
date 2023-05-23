class Registry < ApplicationRecord

  has_many :packages

  def to_param
    name
  end

  def to_s
    name
  end

  def icon_url
    metadata['icon_url']
  end

  def self.sync_all
    conn = Faraday.new('https://packages.ecosyste.ms') do |f|
      f.request :json
      f.request :retry
      f.response :json
    end
    
    response = conn.get('/api/v1/registries')
    return nil unless response.success?
    json = response.body

    json.each do |registry|
      Registry.find_or_create_by(name: registry['name']).tap do |r|
        r.url = registry['url']
        r.ecosystem = registry['ecosystem']
        r.default = registry['default']
        r.packages_count = registry['packages_count']
        r.github = registry['github']
        r.metadata = registry['metadata'].merge('icon_url' => registry['icon_url'])
        r.created_at = registry['created_at']
        r.updated_at = registry['updated_at']
        r.save
      end
    end
  end

  def self.find_by_ecosystem(ecosystem)
    Registry.where(ecosystem: ecosystem, default: true).first || Registry.where(ecosystem: ecosystem).first
  end

  def self.ecosystems
    Registry.pluck('DISTINCT ecosystem')
  end

  def self.package_html_link_for(package)
    find_by_ecosystem(package['ecosystem']).try(:package_html_link_for, package)
  end

  def self.package_api_link_for(package)
    find_by_ecosystem(package['ecosystem']).try(:package_api_link_for, package)
  end

  def self.package_versions_api_link_for(package)
    find_by_ecosystem(package['ecosystem']).try(:package_versions_api_link_for, package)
  end

  def package_html_link_for(package)
    "https://packages.ecosyste.ms/registries/#{name}/packages/#{package['package_name']}"
  end

  def package_api_link_for(package)
    "https://packages.ecosyste.ms/api/v1/registries/#{name}/packages/#{package['package_name']}"
  end

  def package_versions_api_link_for(package)
    "https://packages.ecosyste.ms/api/v1/registries/#{name}/packages/#{package['package_name']}/versions"
  end

  def sync_packages
    conn = Faraday.new('https://packages.ecosyste.ms') do |f|
      f.request :json
      f.request :retry
      f.response :json
    end

    response = conn.get("/api/v1/registries/#{name}/packages?sort=updated_at&order=desc")
    return nil unless response.success?

    links = parse_link_header(response.headers)

    while links['next'].present?
      json = response.body

      json.each do |package|
        Package.find_or_create_by(registry_id: id, name: package['name']).tap do |p|
          p.metadata = package
          p.save
        end
      end
    
      response = conn.get(links['next'])
      return nil unless response.success?
      links = parse_link_header(response.headers)
    end
  end

  def parse_link_header(headers)
    return {} unless headers['Link'].present?

    links = headers['Link'].split(',').map do |link|
      url, rel = link.split(';')
      url = url[/<(.*)>/, 1]
      rel = rel[/rel="(.*)"/, 1]
      [rel, url]
    end

    Hash[links]
  end

  def update_issue_data
    packages.find_each(&:sync_issues) # TODO: make this async in sidekiq
  end

  def package_ids_sorted_by_usage
    @package_ids_sorted_by_usage ||= packages.with_quality.with_usage.order(usage: :asc).pluck(:id)
  end

  def package_ids_sorted_by_quality
    @package_ids_sorted_by_quality ||= packages.with_quality.with_usage.order(quality: :desc).pluck(:id)
  end

  def update_ranks
    @package_ids_sorted_by_usage = nil
    @package_ids_sorted_by_quality = nil
    packages.with_usage.with_quality.each(&:update_ranks);nil
  end
end
