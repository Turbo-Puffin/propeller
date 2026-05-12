require "test_helper"

class SegmentTest < ActiveSupport::TestCase
  setup do
    @account = create_account
  end

  test "is valid with a name and well-formed rules" do
    segment = @account.segments.new(name: "VIPs", rules: { "match" => "all", "rules" => [] })
    assert segment.valid?
  end

  test "requires a name" do
    segment = @account.segments.new(name: "", rules: { "match" => "all", "rules" => [] })
    refute segment.valid?
    assert_includes segment.errors[:name], "can't be blank"
  end

  test "rejects an unknown match mode" do
    segment = @account.segments.new(name: "X", rules: { "match" => "weird", "rules" => [] })
    refute segment.valid?
  end

  test "rejects an unknown operator" do
    segment = @account.segments.new(
      name: "X",
      rules: { "match" => "all", "rules" => [ { "property" => "email", "op" => "blowup", "value" => "x" } ] }
    )
    refute segment.valid?
  end

  test "match_mode defaults to all when not specified" do
    segment = @account.segments.new(name: "X", rules: { "rules" => [] })
    assert_equal "all", segment.match_mode
  end
end
