class DeveloperLinkingService
  class << self

    def create_name_links
    end

    def create_website_links
    end

    def fill_website_match_strings
      batch = Sidekiq::Batch.new
      batch.description = 'Populating website comparisons'
      batch.on(:complete, 'DeveloperLinkingService#fill_website_match_strings')

      batch.jobs do
        DeveloperLinkingWorker.perform_async(:queue_websites)
      end
    end
  end

  def on_complete_match_strings(status, options)
    Slackiq.notify(webhook_name: :main, status: status, title: 'Completed populating match strings')
  end
end
