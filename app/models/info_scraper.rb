class InfoScraper < Scraper
  
  def process(options={})
    @related_objects = [options[:objects]].flatten if options[:objects]
    @objects_with_errors_count = 0
    related_objects.each do |obj|
      begin
        raw_results = parser.process(_data(target_url_for(obj)), self).results
      rescue ScraperError => e
        logger.debug { "*******#{e.message} while processing #{self.inspect}" }
        obj.errors.add_to_base(e.message)
      end
      update_with_results(raw_results, obj, options)
    end
    errors.add_to_base("Problem on all items (see below for details)") if @objects_with_errors_count == related_objects.size
    update_last_scraped if options[:save_results]&&(@objects_with_errors_count != related_objects.size)
    mark_as_problematic if options[:save_results]&&(@objects_with_errors_count == related_objects.size)
    self
  rescue Exception => e # catch other exceptions and store them for display
    mark_as_problematic if options[:save_results] # don't mark if we're just testing
    errors.add_to_base("Exception while processing:\n#{e.message}")
    self
  end
  
  def related_objects
    @related_objects ||= result_model.constantize.find(:all, :conditions => { :council_id => council_id })
  end
  
  def scraping_for
    "info on #{result_model}s from " + (url.blank? ? "#{result_model}'s url" : "<a href='#{url}'>#{url}</a>")
  end
  
  protected
  # overrides method in standard scraper
  def update_with_results(res, obj=nil, options={})
    if !obj.errors.empty? 
      @objects_with_errors_count +=1
      results << ScrapedObjectResult.new(obj)
    elsif !@parser.errors.empty?
      @objects_with_errors_count +=1
      sor = ScrapedObjectResult.new(obj)
      sor.errors.add_to_base @parser.errors[:base]
      results << sor
    elsif !res.blank?
      obj.attributes = res.first
      options[:save_results] ? obj.save : obj.valid? # don't try if we've already got errors
      results << ScrapedObjectResult.new(obj)
    end
    
  end

end