require 'test_helper'

class MembersControllerTest < ActionController::TestCase
  
  def setup
    @member = Factory(:member)
    @council = @member.council
    @ward = Factory(:ward, :council => @council)
    @ward.members << @member
    @committee = Factory(:committee, :council => @council)
    @member.committees << @committee
    @forthcoming_meeting = Factory(:meeting, :council => @council, :committee => @committee, :date_held => 2.days.from_now)
  end
  # show test
   context "on GET to :show" do

     context "with basic request" do
       setup do
         get :show, :id => @member.id
       end

       should_assign_to(:member) { @member }
       should_assign_to(:council) { @council }
       should_assign_to :committees
       should_assign_to(:forthcoming_meetings) { [@forthcoming_meeting] }
       should_respond_with :success
       should_render_template :show
       should_respond_with_content_type 'text/html'
       should "show member name in title" do
         assert_select "title", /#{@member.full_name}/
       end
       should "list committee memberships" do
         assert_select "#committees ul a", @committee.title
       end
       should "list forthcoming meetings" do
         assert_select "#meetings ul a", @forthcoming_meeting.title
       end
       should "show link to meeting calendar" do
         assert_select "#meetings a.calendar[href*='#{@member.id}.ics']"
       end
       
       should "show rdfa headers" do
         assert_select "html[xmlns:foaf*='xmlns.com/foaf']"
       end

       should "show rdfa stuff in head" do
         assert_select "head link[rel*='foaf']"
       end

       should "show rdfa typeof" do
         assert_select "div[typeof*='openlylocal:LocalAuthorityMember']"
       end

       should "use member name as foaf:name" do
         assert_select "h1 span[property*='foaf:name']", @member.full_name
       end

       should "show rdfa attributes for committees" do
         assert_select "#committees li a[rev*='foaf:member']"
       end
       
       should "show foaf attributes for meetings" do
         assert_select "#meetings li[rel*='openlylocal:meeting']"
       end
       
       should "show canonical url" do
         assert_select "link[rel='canonical'][href='/members/#{@member.to_param}']"
       end
     end
     
     context "with xml requested" do
       setup do
         get :show, :id => @member.id, :format => "xml"
       end

       should_assign_to(:member) { @member }
       should_respond_with :success
       should_render_without_layout
       should_respond_with_content_type 'application/xml'

       should "include committees" do
         assert_select "member>committees>committee"
       end

       should "include meetings" do
         assert_select "member>forthcoming-meetings>forthcoming-meeting"
       end

       should "include ward info" do
         assert_select "member>ward>id"
       end
     end

     context "with json requested" do
       setup do
         get :show, :id => @member.id, :format => "json"
       end

       should_assign_to(:member) { @member }
       should_respond_with :success
       should_render_without_layout
       should_respond_with_content_type 'application/json'
       should "include committees" do
         assert_match /committees.+committee/, @response.body
       end
       should "include meetings" do
         assert_match /meetings.+meeting/, @response.body
       end
       should "include ward info" do
         assert_match %r(ward.+name.+#{@ward.name}), @response.body
       end
     end

     context "with ics requested" do
       setup do
         get :show, :id => @member.id, :format => "ics"
       end

       should_assign_to(:member) { @member }
       should_respond_with :success
       should_render_without_layout
       should_respond_with_content_type 'text/calendar'
     end
     
     context "with rdf request" do
       context "for member with full personal details" do
         setup do
           @member.update_attributes(:telephone => "012 345 678", :email => "member@anytown.gov.uk", :address => "2 some street, anytown", :name_title => "Prof")
           get :show, :id => @member.id, :format => "rdf"
         end

         should_assign_to(:member) { @member }
         should_respond_with :success
         should_render_without_layout
         should_respond_with_content_type 'application/rdf+xml'

         should "show rdf headers" do
           assert_match /rdf:RDF.+ xmlns:foaf/m, @response.body
           assert_match /rdf:RDF.+ xmlns:openlylocal/m, @response.body
           assert_match /rdf:RDF.+ xmlns:administrative-geography/m, @response.body
         end

         should "show rdf info for member" do
           assert_match /rdf:Description.+rdf:about.+\/members\/#{@member.id}/, @response.body
           assert_match /rdf:Description.+rdfs:label>#{@member.title}/m, @response.body
           assert_match /rdf:type.+openlylocal:LocalAuthorityMember/m, @response.body
         end

         should "show personal info for member with info" do
           assert_match /rdf:Description.+foaf:name.+#{@member.full_name}/m, @response.body
           assert_match /rdf:Description.+foaf:page.+#{@member.url}/m, @response.body
           assert_match /rdf:Description.+foaf:title.+#{@member.name_title}/m, @response.body
           assert_match /rdf:Description.+foaf:phone.+#{Regexp.escape(@member.foaf_telephone)}/m, @response.body
           assert_match /rdf:Description.+foaf:mbox.+mailto:#{@member.email}/m, @response.body
         end
         
         should "show address for member as vCard" do
           assert_match /rdf:Description.+vCard:ADR.+vCard:Extadd.+#{Regexp.escape(@member.address)}/m, @response.body
         end
         
         should "show committee memberships" do
           assert_match /rdf:Description.+\/committees\/#{@committee.id}.+foaf:member.+\/members\/#{@member.id}/m, @response.body
         end
         
         should "show council membership" do
           assert_match /rdf:Description.+\/councils\/#{@council.id}.+foaf:member.+\/members\/#{@member.id}/m, @response.body
         end

       end

       context "for member without full personal details" do
         setup do
           get :show, :id => @member.id, :format => "rdf"
         end

         should_assign_to(:member) { @member }
         should_respond_with :success
         should_render_without_layout
         should_respond_with_content_type 'application/rdf+xml'

         should "not show personal info for member without info" do
           assert_match /rdf:Description.+foaf:name.+#{@member.full_name}/m, @response.body
           assert_match /rdf:Description.+foaf:page.+#{@member.url}/m, @response.body
           assert_no_match /rdf:Description.+foaf:title/m, @response.body
           assert_no_match /rdf:Description.+foaf:phone/m, @response.body
           assert_no_match /rdf:Description.+foaf:mbox/m, @response.body
         end
         should "show not address for member" do
           assert_no_match /rdf:Description.+vCard:ADR/m, @response.body
         end
         
         should "show council membership" do
           assert_match /rdf:Description.+\/councils\/#{@council.id}.+foaf:member.+\/members\/#{@member.id}/m, @response.body
         end

       end
     end
   end  
   
   context "on get to :edit a scraper without auth" do
     setup do
       get :edit, :id => @member.id
     end

     should_respond_with 401
   end

   context "on get to :edit a scraper" do
     setup do
       stub_authentication
       get :edit, :id => @member.id
     end

     should_assign_to :member
     should_respond_with :success
     should_render_template :edit
     should_not_set_the_flash
     should "display a form" do
      assert_select "form#edit_member_#{@member.id}"
     end
     

     should "show button to delete member" do
       assert_select "form.button-to[action='/members/#{@member.to_param}']"
     end
   end

   # update tests
   context "on PUT to :update without auth" do
     setup do
       put :update, { :id => @member.id, 
                      :member => { :uid => 44, 
                                 :name => "New name"}}
     end

     should_respond_with 401
   end

   context "on PUT to :update" do
     setup do
       stub_authentication
       put :update, { :id => @member.id, 
                      :member => { :uid => 44, 
                                   :full_name => "New name"}}
     end

     should_assign_to :member
     should_redirect_to( "the show page for member") { member_path(@member.reload) }
     should_set_the_flash_to "Successfully updated member"

     should "update member" do
       assert_equal "New name", @member.reload.full_name
     end
   end

   # delete tests
   context "on delete to :destroy a member without auth" do
     setup do
       delete :destroy, :id => @member.id
     end

     should_respond_with 401
   end

   context "on delete to :destroy a member" do

     setup do
       stub_authentication
       delete :destroy, :id => @member.id
     end

     should "destroy member" do
       assert_nil Member.find_by_id(@member.id)
     end
     should_redirect_to ( "the council page") { council_url(@council) }
     should_set_the_flash_to "Successfully destroyed member"
   end
end
