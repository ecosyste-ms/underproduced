class Package < ApplicationRecord
  belongs_to :registry

  scope :with_issue_data, -> { where.not(issue_data: nil) }

  scope :with_usage, -> { where.not(usage: nil) }
  scope :with_quality, -> { where.not(quality: nil) }
  scope :with_production, -> { where.not(production: nil) }

  scope :without_usage, -> { where(usage: nil) }
  scope :without_quality, -> { where(quality: nil) }
  scope :without_production, -> { where(production: nil) }

  def to_param
    name
  end

  def repo_metadata
    metadata['repo_metadata']
  end

  def repo_url
    repo_metadata['html_url'] if repo_metadata.present?
  end

  def downloads
    metadata['downloads']
  end

  def downloads_period
    metadata['downloads_period']
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

    # follow redirects
    conn = Faraday.new('https://issues.ecosyste.ms') do |f|
      f.request :json
      f.request :retry
      f.response :json
      f.use Faraday::FollowRedirects::Middleware
    end

    response = conn.get("/api/v1/repositories/lookup?url=#{repo_metadata['html_url']}")
    return nil unless response.success?
    json = response.body

    update(issue_data: json, last_synced_at: Time.now.utc)
    set_sort_fields
  end

  def update_ranks
    return unless usage.present? && quality.present?

    

    self.usage_rank = calculate_usage_rank
    self.quality_rank = calculate_quality_rank
    self.production = Math.log(usage_rank/quality_rank.to_f)
    save
  end

  def set_sort_fields
    self.usage = metadata['downloads']
    self.quality = issue_data['avg_time_to_close_issue'] if issue_data.present?
    save
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
end
