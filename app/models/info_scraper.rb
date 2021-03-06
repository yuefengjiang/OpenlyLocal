class InfoScraper < Scraper
  
  def process(options={})
    mark_as_unproblematic # clear problematic flag. It will be reset if there's a prob
    @related_objects = [options[:objects]].flatten if options[:objects]
    @objects_with_errors_count = 0
    @timeout_errors = false
    dont_update_last_scraped = options.delete(:dont_update_last_scraped)
    related_objects.each do |obj|
      begin
        html = _data(target_url_for(obj))
        logger.debug "HTML = #{html}"
        raw_results = parser.process(html, self).results
      rescue ScraperError => e
        logger.debug { "*******#{e.message} while processing #{self.inspect}" }
        @timeout_errors = true if e.is_a?(WebsiteUnavailable) # we just need to track whether there are any timeout/503 errors
        obj.errors.add_to_base(e.message)
      end
      update_with_results(raw_results, obj, options)
    end
    errors.add_to_base("Problem on all items (see below for details)") if (related_objects.size > 0)&&(@objects_with_errors_count == related_objects.size)
    update_last_scraped if options[:save_results]&&(@objects_with_errors_count != related_objects.size) && !dont_update_last_scraped
    mark_as_problematic if options[:save_results]&&(related_objects.size > 0)&&(@objects_with_errors_count == related_objects.size) && !@timeout_errors
    self
  rescue Exception => e # catch other exceptions and store them for display
    mark_as_problematic if options[:save_results] # don't mark if we're just testing
    errors.add_to_base("Exception while processing:\n#{e.message}")
    logger.debug { "***Exception while processing:\n#{e.message}:\n\n#{e.backtrace}" }
    self
  end
  
  def related_objects
    case 
    when @related_objects
      @related_objects
    else
      if parser.bitwise_flag 
        result_model.constantize.stale.with_clear_bitwise_flag(parser.bitwise_flag).find(:all, :conditions => { :council_id => council_id })
      else
        result_model.constantize.stale.find(:all, :conditions => { :council_id => council_id })
      end
    end
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
      first_res = res.first # results are returned as an array containing just one object. I think.
      first_res.merge!(:retrieved_at => Time.now) if obj.attribute_names.include?('retrieved_at') # update timestamp if model has one
      obj.attributes = obj.clean_up_raw_attributes(first_res)
      options[:save_results] ? obj.save : obj.valid? # don't try if we've already got errors
      results << ScrapedObjectResult.new(obj)
    end
    
  end

end