require 'test_helper'

class CommitteesControllerTest < ActionController::TestCase
  # show test
   context "on GET to :show for first record" do
     setup do
       @committee = Factory(:committee)
       get :show, :id => @committee.id
     end

     should_assign_to :committee
     should_respond_with :success
     should_render_template :show

   end  

   # index test
   context "on GET to :index with council_id" do
     setup do
       @committee = Factory(:committee)
       @council = @committee.council
       Factory.create(:committee, :council_id => @council.id, :uid =>@committee.uid+1, :title => "another committee", :url => "http://foo.com" )
       Factory.create(:committee, :council_id => Factory(:another_council).id, :uid => @committee.uid+1, :title => "another council's committee", :url => "http://foo.com" )
       get :index, :council_id => @council.id
     end

     should_assign_to :committees
     should_assign_to(:council) { @council }
     should_respond_with :success
     should_render_template :index
     should "should list committees for council" do
       assert_select "ul li", 2 do
        
       end
     end
   end
   
   context "on GET to :index without council_id" do
     setup do
       @committee = Factory(:committee)
     end

     # should_respond_with :failure
     should "raise an exception" do
       assert_raise(ActiveRecord::RecordNotFound) { get :index }
     end
   end
   
end
