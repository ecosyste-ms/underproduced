module ApplicationHelper
  def meta_title
    [@meta_title, 'Ecosyste.ms: Underproduced'].compact.join(' | ')
  end

  def meta_description
    @meta_description || 'An investigation into underproduced open source software.'
  end

  def download_period(downloads_period)
    case downloads_period
    when "last-month"
      "last month"
    when "total"
      "total"
    end
  end

  def distance_of_time_in_words_if_present(time)
    return 'N/A' unless time
    distance_of_time_in_words(time)
  end
end
