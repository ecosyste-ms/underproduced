class Package < ApplicationRecord
  belongs_to :registry

  scope :with_issue_data, -> { where.not(issue_data: nil) }

  scope :with_usage, -> { where.not(usage: nil) }
  scope :with_quality, -> { where.not(quality: nil) }
  scope :with_production, -> { where.not(production: nil) }
  scope :with_downloads, -> { where.not(downloads: nil) }
  scope :with_dependent_repos_count, -> { where.not(dependent_repos_count: nil) }
  scope :with_issues_closed_count, -> { where.not(issues_closed_count: nil).where('issues_closed_count > 0') }
  scope :with_issues_count, -> { where.not(issues_count: nil).where('issues_count > 0') }

  scope :without_usage, -> { where(usage: nil) }
  scope :without_quality, -> { where(quality: nil) }
  scope :without_production, -> { where(production: nil) }

  def to_param
    name
  end

  def html_url
    metadata['html_url']
  end

  def repo_metadata
    metadata['repo_metadata']
  end

  def repo_url
    repo_metadata['html_url'] if repo_metadata.present?
  end

  def stars
    repo_metadata['stargazers_count'] if repo_metadata.present?
  end

  def description_with_fallback
    metadata['description'].presence || repo_metadata && repo_metadata['description']
  end

  def latest_release_number
    metadata['latest_release_number']
  end

  def sync_issues
    return unless repo_metadata.present?

    conn = Faraday.new('https://issues.ecosyste.ms') do |f|
      f.request :json
      f.request :retry
      f.response :json
      f.use Faraday::FollowRedirects::Middleware
    end

    response = conn.get("/api/v1/repositories/lookup?url=#{repo_metadata['html_url']}")
    return nil unless response.success?
    json = response.body

    update({
      issue_data: json, 
      last_synced_at: Time.now.utc,
      avg_time_to_close_issue: json['avg_time_to_close_issue'],
      issues_closed_count: json['issues_closed_count'],
      issues_count: json['issues_count'],
      usage: usage_field,
      quality: json['avg_time_to_close_issue']
    })
  end

  def sync_issues_async
    SyncIssuesWorker.perform_async(registry_id, id)
  end

  def update_ranks
    return unless usage.present? && quality.present?

    self.usage_rank = calculate_usage_rank
    self.quality_rank = calculate_quality_rank
    self.production = Math.log(usage_rank/quality_rank.to_f)
    save
  end

  def usage_field
    metadata['downloads'] || metadata['dependent_repos_count']
  end

  def calculate_usage_rank
    registry.package_ids_sorted_by_usage.index(id) + 1
  end

  def calculate_quality_rank
    registry.package_ids_sorted_by_quality.index(id) + 1
  end

  def calculate_production
    Math.log(usage_rank/quality_rank.to_f)
  end

  def ping
    Faraday.get(packages_api_url + '/ping')
  end

  def issues_api_url
    return nil unless issue_data.present?
    issue_data['repository_url']
  end

  def issues_url
    return nil unless issue_data.present?
    issues_api_url.gsub('api/v1/', '')
  end

  def repos_api_url
    return nil unless repo_metadata.present?
    repo_metadata['repository_url']
  end

  def repos_url
    return nil unless repo_metadata.present?
    repos_api_url.gsub('api/v1/', '')
  end

  def packages_url
    "https://packages.ecosyste.ms/registries/#{registry.name}/packages/#{name}"
  end

  def packages_api_url
    "https://packages.ecosyste.ms/api/v1/registries/#{registry.name}/packages/#{name}"
  end
end
