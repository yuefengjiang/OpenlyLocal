require File.expand_path('../../../test_helper', __FILE__)

class ScrapersHelperTest < ActionView::TestCase

  include ApplicationHelper
  include ScrapersHelper
  
  context "class_for_result helper method" do

    should "return empty string by default" do
      assert_equal "unchanged", class_for_result(stub_everything(:errors => []))
    end
    
    should "return new when record is new" do
      assert_equal "new", class_for_result(stub_everything(:new_record? => true, :errors => []))
    end
    
    should "return new when record was new before saving" do
      assert_equal "new", class_for_result(stub_everything(:new_record_before_save? => true, :errors => []))
    end
    
    should "return error when record has errors" do
      assert_equal "unchanged error", class_for_result(stub_everything(:errors => ["foo"]))
    end
    
    should "return changed when record has changed" do
      assert_equal "changed", class_for_result(stub_everything(:changed? => true, :errors => []))
    end
    
    should "return just new when record is new and has changed" do
      assert_equal "new", class_for_result(stub_everything(:changed? => true, :new_record? => true, :errors => []))
    end
    
    should "return multiple class when record is new and has errors" do
      assert_equal "new error", class_for_result(stub_everything(:errors => ["foo"], :new_record? => true))
    end
  end
  
  context "flash_for_result helper method" do

    should "return empty string by default" do
      assert_nil flash_for_result(nil)
    end
    
    should "return empty string by default if result is unchanged" do
      assert_nil flash_for_result(stub_everything(:status => "unchanged"))
    end
    
    should "return nil if status nil" do
      assert_nil flash_for_result(stub_everything(:status => nil))
    end

    should "return status of result" do
      assert_dom_equal "<span class='foo flash'>foo</span>", flash_for_result(stub_everything(:status => "foo"))
    end
    
    should "return mutiple class but error text when record is new and has errors" do
      assert_dom_equal "<span class='foo errors flash'>errors</span>", flash_for_result(stub_everything(:status => "foo errors"))
    end
    
    
  end
  
  context "changed_attributes_list helper method" do
    setup do
      @member = Factory.create(:member)
      @member.save # save again so record is not newly created
    end
    
    should "show message if no changed attributes" do
       assert_dom_equal content_tag(:div, "Record is unchanged"), changed_attributes_list(ScrapedObjectResult.new(@member))      
     end
     
     should "show message if changes blank?" do
       assert_dom_equal content_tag(:div, "Record is unchanged"), changed_attributes_list(ScrapedObjectResult.new)      
     end

     should "list only attributes that have changed" do
       @member.first_name = "Pete"
       @member.telephone = "0123 456 789"
       assert_dom_equal content_tag(:div, content_tag(:ul, content_tag(:li, "telephone <strong>0123 456 789</strong> (was empty)") + 
                                                           content_tag(:li, "first_name <strong>Pete</strong> (was Bob)")), 
                                          :class => "changed_attributes"), changed_attributes_list(ScrapedObjectResult.new(@member))
     end
     
     should "show inspect view of attributes that are hashes" do
       expected_res = content_tag(:div, content_tag(:ul, content_tag(:li, "other_attributes <strong>{:foo=>\"bar\"}</strong> (was empty)")), 
                                        :class => "changed_attributes")
       assert_dom_equal expected_res, changed_attributes_list(ScrapedObjectResult.new(PlanningApplication.new(:other_attributes => {:foo => 'bar'})))      
     end

  end
 
  context "scraper_links_for_council helper method" do
    setup do
      @scraper = Factory(:scraper, :next_due => 1.day.from_now)
      @council = @scraper.council
    end

    should "return array" do
      assert_kind_of Array, scraper_links_for_council(@council)
    end
    
    should "return array of links for council's scrapers" do
      assert_equal link_for(@scraper), scraper_links_for_council(@council).first
    end
    
    should "return links for all possible scrapers" do
      assert_equal Scraper::SCRAPER_TYPES.size*Parser::ALLOWED_RESULT_CLASSES.size, scraper_links_for_council(@council).size
    end
    
    should "class as problematic if scraper is problematic" do
      @scraper.class.any_instance.stubs(:problematic?).returns(true)
      scraper_link = Nokogiri.HTML( scraper_links_for_council(@council).first)
      assert scraper_link.at('a.problematic')
    end
    
    should "class as stale if scraper is stale" do
      @scraper.class.any_instance.stubs(:stale?).returns(true)
      scraper_link = Nokogiri.HTML( scraper_links_for_council(@council).first)
      assert scraper_link.at('a.stale')
    end
    
    should "class as problematic and stale if scraper is problematic and stale" do
      expected_link = link_for(@scraper, :class => "stale problematic")
      @scraper.class.any_instance.stubs(:stale?).returns(true)
      @scraper.class.any_instance.stubs(:problematic?).returns(true)
      scraper_link = Nokogiri.HTML( scraper_links_for_council(@council).first)
      assert scraper_link.at('a.stale')
      assert scraper_link.at('a.problematic')
    end
    
    should "return links for not yet created scrapers" do
      links = scraper_links_for_council(@council)
      assert links.include?(link_to("Add Committee item scraper for #{@council.name} council", new_scraper_path(:council_id => @council.id, :result_model => "Committee", :type => "ItemScraper"), :class => "new_scraper_link")) 
    end
  end
     
  context "existing_scraper_links helper method" do
    setup do
      @scraper = Factory(:scraper, :last_scraped => 2.days.ago)
      @council = @scraper.council
    end

    should "return array" do
      assert_kind_of Array, existing_scraper_links(@council)
    end
    
    should "return array of links for council's scrapers and links to process them" do
      expected_result = link_for(@scraper) + ' ' +  link_to('process', scrape_scraper_url(@scraper), :class => 'button process_scraper') 
      assert_equal expected_result, existing_scraper_links(@council).first
    end
    
    should "return links for all existing scrapers" do
      assert_equal 1, existing_scraper_links(@council).size
    end
    
    # should "return links for all possible scrapers" do
    #   assert_equal Scraper::SCRAPER_TYPES.size*Parser::ALLOWED_RESULT_CLASSES.size, scraper_links_for_council(@council).size
    # end
    # 
    # should "class as problem if scraper is problematic" do
    #   @scraper.class.any_instance.stubs(:problematic?).returns(true)
    #   assert_equal link_for(@scraper, :class => "problematic"), scraper_links_for_council(@council).first
    # end
    # 
    # should "class as stale if scraper is stale" do
    #   @scraper.class.any_instance.stubs(:stale?).returns(true)
    #   assert_equal link_for(@scraper, :class => "stale"), scraper_links_for_council(@council).first
    # end
    # 
    # should "class as problem and stale if scraper is problematic and stale" do
    #   @scraper.class.any_instance.stubs(:stale?).returns(true)
    #   @scraper.class.any_instance.stubs(:problematic?).returns(true)
    #   assert_equal link_for(@scraper, :class => "stale problematic"), scraper_links_for_council(@council).first
    # end
    # 
    # should "return links for not yet created scrapers" do
    #   links = scraper_links_for_council(@council)
    #   assert links.include?(link_to("Add Committee item scraper for #{@council.name} council", new_scraper_path(:council_id => @council.id, :result_model => "Committee", :type => "ItemScraper"), :class => "new_scraper_link")) 
    # end
  end
     
end
