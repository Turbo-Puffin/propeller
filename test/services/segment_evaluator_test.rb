require "test_helper"
require "benchmark"

class Services::SegmentEvaluatorTest < ActiveSupport::TestCase
  setup do
    @account = create_account
    @list = @account.contact_lists.create!(name: "Main")
    @contact = @account.contacts.create!(
      email: "ada@example.com",
      first_name: "Ada",
      subscribed_at: Time.zone.parse("2026-04-15"),
      metadata: { "tags" => [ "newsletter", "vip" ], "score" => 87 }
    )
    @list.contact_list_memberships.create!(contact: @contact)
  end

  # --- string operators ---

  test "equals matches on a direct column" do
    assert evaluator(prop: "email", op: "equals", val: "ada@example.com").matches?(@contact)
    refute evaluator(prop: "email", op: "equals", val: "bob@example.com").matches?(@contact)
  end

  test "not_equals is the inverse of equals" do
    refute evaluator(prop: "email", op: "not_equals", val: "ada@example.com").matches?(@contact)
    assert evaluator(prop: "email", op: "not_equals", val: "bob@example.com").matches?(@contact)
  end

  test "starts_with / ends_with / contains" do
    assert evaluator(prop: "email", op: "starts_with", val: "ada").matches?(@contact)
    assert evaluator(prop: "email", op: "ends_with", val: "@example.com").matches?(@contact)
    assert evaluator(prop: "email", op: "contains", val: "@example").matches?(@contact)
  end

  test "matches_regex evaluates safely with bad pattern" do
    refute evaluator(prop: "email", op: "matches_regex", val: "[invalid(").matches?(@contact)
    assert evaluator(prop: "email", op: "matches_regex", val: "\\Aada").matches?(@contact)
  end

  # --- numeric / date operators ---

  test "greater_than / less_than coerce numbers from metadata" do
    assert evaluator(prop: "metadata.score", op: "greater_than", val: 50).matches?(@contact)
    refute evaluator(prop: "metadata.score", op: "greater_than", val: 200).matches?(@contact)
    assert evaluator(prop: "metadata.score", op: "less_than", val: 100).matches?(@contact)
  end

  test "before / after compare dates" do
    assert evaluator(prop: "subscribed_at", op: "after", val: "2026-04-01").matches?(@contact)
    refute evaluator(prop: "subscribed_at", op: "before", val: "2026-04-01").matches?(@contact)
  end

  test "between with date range" do
    assert evaluator(prop: "subscribed_at", op: "between", val: [ "2026-04-01", "2026-05-01" ]).matches?(@contact)
    refute evaluator(prop: "subscribed_at", op: "between", val: [ "2026-05-01", "2026-06-01" ]).matches?(@contact)
  end

  # --- membership operators ---

  test "in_list / not_in_list use contact_list_memberships" do
    assert evaluator(prop: "list", op: "in_list", val: @list.id).matches?(@contact)
    refute evaluator(prop: "list", op: "not_in_list", val: @list.id).matches?(@contact)
  end

  # --- tag / array operators ---

  test "includes / excludes on tags" do
    assert evaluator(prop: "tag", op: "includes", val: "newsletter").matches?(@contact)
    refute evaluator(prop: "tag", op: "includes", val: "missing").matches?(@contact)
    assert evaluator(prop: "tag", op: "excludes", val: "missing").matches?(@contact)
  end

  test "any_of / all_of on tags" do
    assert evaluator(prop: "tag", op: "any_of", val: [ "vip", "absent" ]).matches?(@contact)
    refute evaluator(prop: "tag", op: "any_of", val: [ "absent", "ghost" ]).matches?(@contact)
    assert evaluator(prop: "tag", op: "all_of", val: [ "vip", "newsletter" ]).matches?(@contact)
    refute evaluator(prop: "tag", op: "all_of", val: [ "vip", "absent" ]).matches?(@contact)
  end

  # --- engagement operators (permissive for v1) ---

  test "engagement operators return true until send data lands" do
    %w[opened_within_days not_opened_within_days clicked_within_days].each do |op|
      assert evaluator(prop: "email", op: op, val: 30).matches?(@contact), "expected #{op} to be permissive"
    end
  end

  # --- match modes ---

  test "match=all requires every rule" do
    segment = build_segment(
      "match" => "all",
      "rules" => [
        { "property" => "email", "op" => "ends_with", "value" => "@example.com" },
        { "property" => "first_name", "op" => "equals", "value" => "Ada" }
      ]
    )
    assert segment.matches?(@contact)
  end

  test "match=all returns false when a rule fails" do
    segment = build_segment(
      "match" => "all",
      "rules" => [
        { "property" => "email", "op" => "ends_with", "value" => "@example.com" },
        { "property" => "first_name", "op" => "equals", "value" => "Grace" }
      ]
    )
    refute segment.matches?(@contact)
  end

  test "match=any only needs one rule to pass" do
    segment = build_segment(
      "match" => "any",
      "rules" => [
        { "property" => "first_name", "op" => "equals", "value" => "Grace" },
        { "property" => "email", "op" => "ends_with", "value" => "@example.com" }
      ]
    )
    assert segment.matches?(@contact)
  end

  test "nil property does not raise" do
    contact = @account.contacts.create!(email: "no-meta@example.com")
    refute evaluator(prop: "metadata.missing", op: "equals", val: "x").matches?(contact)
    refute evaluator(prop: "tag", op: "includes", val: "anything").matches?(contact)
  end

  # --- matching_scope (SQL pushdown) ---

  test "matching_scope returns an ActiveRecord scope" do
    segment = build_segment(
      "match" => "all",
      "rules" => [ { "property" => "email", "op" => "ends_with", "value" => "@example.com" } ]
    )
    scope = segment.matching_scope
    assert_kind_of ActiveRecord::Relation, scope
    assert_includes scope.pluck(:id), @contact.id
  end

  test "matching_scope filters by metadata in SQL" do
    @account.contacts.create!(email: "other@example.com", metadata: { "tags" => [ "newsletter" ] })
    segment = build_segment(
      "match" => "all",
      "rules" => [ { "property" => "tag", "op" => "includes", "value" => "vip" } ]
    )
    ids = segment.matching_scope.pluck(:id)
    assert_equal [ @contact.id ], ids
  end

  test "matching_scope respects account isolation" do
    other_account = create_account(name: "Other")
    other_account.contacts.create!(email: "ada@example.com", first_name: "Ada")

    segment = build_segment("match" => "all", "rules" => [ { "property" => "first_name", "op" => "equals", "value" => "Ada" } ])
    ids = segment.matching_scope.pluck(:account_id).uniq
    assert_equal [ @account.id ], ids
  end

  test "matching_scope honors contact_list scoping when present" do
    list_a = @account.contact_lists.create!(name: "A")
    list_b = @account.contact_lists.create!(name: "B")
    in_a = @account.contacts.create!(email: "a@example.com", first_name: "A")
    in_b = @account.contacts.create!(email: "b@example.com", first_name: "B")
    list_a.contact_list_memberships.create!(contact: in_a)
    list_b.contact_list_memberships.create!(contact: in_b)

    segment = @account.segments.create!(
      name: "List A members",
      contact_list: list_a,
      rules: { "match" => "all", "rules" => [] }
    )
    ids = segment.matching_scope.pluck(:id)
    assert_includes ids, in_a.id
    refute_includes ids, in_b.id
  end

  test "matching_scope evaluates 10k contacts in under 500ms" do
    # Bulk insert directly to bypass per-record validations.
    rows = 10_000.times.map do |i|
      {
        id: SecureRandom.uuid,
        account_id: @account.id,
        email: "bulk-#{i}@example.com",
        first_name: i.even? ? "Even" : "Odd",
        metadata: { "tags" => i % 5 == 0 ? [ "vip" ] : [] },
        status: 0,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    Contact.insert_all(rows)

    segment = build_segment(
      "match" => "all",
      "rules" => [
        { "property" => "first_name", "op" => "equals", "value" => "Even" },
        { "property" => "tag", "op" => "includes", "value" => "vip" }
      ]
    )

    elapsed = Benchmark.realtime { segment.matching_scope.count }
    assert elapsed < 0.5, "matching_scope took #{(elapsed * 1000).round}ms — target <500ms"
  end

  private

  def evaluator(prop:, op:, val:)
    build_segment("match" => "all", "rules" => [ { "property" => prop, "op" => op, "value" => val } ])
  end

  def build_segment(rules)
    @account.segments.create!(name: "test-#{SecureRandom.hex(4)}", rules: rules)
  end
end
