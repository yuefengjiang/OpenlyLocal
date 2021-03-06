class FeedEntry < ActiveRecord::Base
  belongs_to :feed_owner, :polymorphic => true
  acts_as_taggable
  validates_presence_of :guid, :url, :title
  named_scope :for_blog, :conditions => {:feed_owner_type => nil, :feed_owner_id => nil}
  named_scope :restrict_to, lambda { |restricted_type| restricted_type ?  { :conditions => {:feed_owner_type => restricted_type.classify} } : { } }
  default_scope :order => "published_at DESC"
  
  def self.update_from_feed(owner_or_url)
    url = owner_or_url.is_a?(String) ? owner_or_url : owner_or_url.feed_url
    feed_owner = owner_or_url.is_a?(String) ? nil : owner_or_url
    Feedzirra::Feed.add_common_feed_entry_element('georss:point', :as => :point)
    feed = Feedzirra::Feed.fetch_and_parse(url)
    add_entries(feed.entries, :feed_owner => feed_owner)
  end
  
  def self.perform
    items = Council.all(:conditions => "feed_url IS NOT NULL AND feed_url <> ''")
    items += HyperlocalSite.all(:conditions => "feed_url IS NOT NULL AND feed_url <> ''")
    items << BlogFeedUrl
    errors = []
    items.each do |item|
      begin
        update_from_feed(item)
        logger.debug { "Successfully update feed entries for #{item.inspect}" }
      rescue Exception => e
        logger.debug { "Problem getting feed entries for #{item.inspect}: #{e.inspect}" }
        errors << [e, item]
        items.delete(item)
      end
    end
    errors_text = "\n========\n#{errors.size} problems" + 
                    errors.collect{ |err, item| "\n#{err.inspect} raised while getting feed entries from " + 
                    (item.is_a?(String) ? item : "#{item.feed_url} (#{item.title})") }.join
    AdminMailer.deliver_admin_alert!( :title => "RSS Feed Updating Report: #{items.size} successes, #{errors.size} problems", 
                                      :details => "Successfullly updated feeds for #{items.size} items\n" + errors_text)
  end
  
  def point=(geo_rss_point)
    return unless geo_rss_point
    self.lat,self.lng = geo_rss_point.split(/,|\s/)
  end
  
  private
  def self.add_entries(entries, options={})
    entries.each do |entry|
      unless exists? :guid => entry.id
        create!(
          :title        => entry.title,
          :summary      => (entry.summary&&strip_tags_and_line_breaks(entry.summary))||(entry.content&&summarize_content(entry.content)),
          :url          => entry.url,
          :published_at => entry.published,
          :guid         => entry.id,
          :point        => entry.point,
          :tag_list     => entry.categories,
          :feed_owner   => options[:feed_owner]
        )
      end
    end
  end
  
  def self.summarize_content(content)
    h_content = CGI::unescapeHTML(content).gsub(/(<br[ \/]{0,2}>)+/, ' ')
    strip_tags_and_line_breaks(h_content)
  end
  
  def self.strip_tags_and_line_breaks(html_content)
    ActionController::Base.helpers.strip_tags(html_content).gsub(/[\t\r\n]+/," ")
  end
  
end
