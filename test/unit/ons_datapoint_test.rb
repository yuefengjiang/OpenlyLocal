require 'test_helper'

class OnsDatapointTest < ActiveSupport::TestCase
  subject { @ons_datapoint }
  context "The OnsDatapoint class" do
    setup do
      @ons_datapoint = Factory(:ons_datapoint)
    end

    should_validate_presence_of :value
    should_validate_presence_of :ons_dataset_topic_id
    should_validate_presence_of :area_id
    should_validate_presence_of :area_type
    should_belong_to :ons_dataset_topic
    should_belong_to :area
    should "belong_to ons_dataset_family through ons_dataset_topic" do
      assert_equal @ons_datapoint.ons_dataset_topic.ons_dataset_family, @ons_datapoint.ons_dataset_family
    end

    should "restrict to given ness topic ids" do
      @ward = @ons_datapoint.area
      ons_datapoint_1 = Factory(:ons_datapoint, :area => @ward)
      ons_datapoint_2 = Factory(:ons_datapoint, :area => @ward)
      ons_datapoint_3 = Factory(:ons_datapoint, :area => @ward)
      topic_uids = [ ons_datapoint_2.ons_dataset_topic.ons_uid,
                     ons_datapoint_3.ons_dataset_topic.ons_uid]
      assert_equal [ons_datapoint_2, ons_datapoint_3], OnsDatapoint.with_topic_uids(topic_uids)
    end
  end

  context "an OnsDatapoint instance" do
    setup do
      @ons_dataset_topic = Factory(:ons_dataset_topic, :muid => 1)
      @ons_datapoint = Factory(:ons_datapoint, :ons_dataset_topic => @ons_dataset_topic)
      @ward = @ons_datapoint.area
    end

    should "include topic id in title" do
      assert_equal "#{@ons_dataset_topic.title}", @ons_datapoint.title
    end

    should "include ward and topic in extended title" do
      assert_equal "#{@ons_dataset_topic.title} (#{@ward.name})", @ons_datapoint.extended_title
    end

    should "delegate muid_format to ons_dataset_topic" do
      @ons_dataset_topic.stubs(:muid_format).returns('%1f')
      assert_equal '%1f', @ons_datapoint.muid_format
    end

    should "delegate muid_type to ons_dataset_topic" do
      @ons_dataset_topic.stubs(:muid_type).returns('foo')
      assert_equal 'foo', @ons_datapoint.muid_type
    end

    should "delegate short_title to ons_dataset_topic" do
      @ons_dataset_topic.stubs(:short_title).returns('short titl')
      assert_equal 'short titl', @ons_datapoint.short_title
    end

    context "when returning related datapoints" do
      context "and area is a ward" do
        setup do
          @sibling_ward = Factory(:ward, :name => 'A sibling ward', :council => @ward.council)
          @unrelated_ward = Factory(:ward, :name => 'Unrelated ward', :council => Factory(:another_council))
          @same_topic_sibling_ward_dp = Factory(:ons_datapoint, :ons_dataset_topic => @ons_dataset_topic, :area => @sibling_ward)
          @same_topic_unrelated_ward_dp = Factory(:ons_datapoint, :ons_dataset_topic => @ons_dataset_topic, :area => @unrelated_ward)
          @different_topic_and_sibling_ward_dp = Factory(:ons_datapoint, :area => @sibling_ward)
        end

        should "include datapoints for same topic from sibling wards" do
          assert @ons_datapoint.related_datapoints.include?(@same_topic_sibling_ward_dp)
        end

        should "include original datapoint" do
          assert @ons_datapoint.related_datapoints.include?(@ons_datapoint)
        end

        should "not include datapoints for same topic from other wards" do
          assert !@ons_datapoint.related_datapoints.include?(@same_topic_unrelated_ward_dp)
        end

        should "not include datapoints for same ward from other topics" do
          assert !@ons_datapoint.related_datapoints.include?(@different_topic_and_sibling_ward_dp)
        end

        should "return datapoints in alphabetical order on wards" do
          assert_equal @same_topic_sibling_ward_dp, @ons_datapoint.related_datapoints.first
        end
      end

      context "and area is a council" do
        setup do
          @council = @ward.council
          @council.update_attribute(:authority_type, "District")
          @ons_datapoint.area = @council
          @ons_datapoint.save!
          @sibling_council = Factory(:council, :name => 'Sibling council', :authority_type => "District")
          @unrelated_council = Factory(:council, :name => 'Unrelated council', :authority_type => "County")
          @same_topic_sibling_council_dp = Factory(:ons_datapoint, :ons_dataset_topic => @ons_dataset_topic, :area => @sibling_council)
          @same_topic_unrelated_council_dp = Factory(:ons_datapoint, :ons_dataset_topic => @ons_dataset_topic, :area => @unrelated_council)
          @different_topic_and_sibling_council_dp = Factory(:ons_datapoint, :area => @sibling_council)
        end

        should "include datapoints for same topic from sibling wards" do
          assert @ons_datapoint.related_datapoints.include?(@same_topic_sibling_council_dp)
        end

        should "include original datapoint" do
          assert @ons_datapoint.related_datapoints.include?(@ons_datapoint)
        end

        should "not include datapoints for same topic from other wards" do
          assert !@ons_datapoint.related_datapoints.include?(@same_topic_unrelated_council_dp)
        end

        should "not include datapoints for same ward from other topics" do
          assert !@ons_datapoint.related_datapoints.include?(@different_topic_and_sibling_council_dp)
        end

        should "return datapoints in alphabetical order on councils" do
          assert_equal @ons_datapoint, @ons_datapoint.related_datapoints.first
        end
      end
    end
  end
end
