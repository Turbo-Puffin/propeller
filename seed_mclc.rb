account = Account.find_by!(subdomain: "turbopuffin")

mclc_list = ContactList.create!(account: account, name: "MCLC Studios", description: "Art collectors and studio followers - new work announcements and exhibition invites")

mclc_form = Form.create!(
  account: account,
  name: "MCLC Studios Embed",
  form_type: :embedded,
  status: :active,
  success_message: "Welcome to the studio! You will be the first to see new work.",
  settings: { "brand" => "mclc-studios", "domain" => "mclcstudios.com" }
)

mclc_seq = EmailSequence.create!(
  account: account,
  name: "MCLC Studios Welcome",
  description: "Welcome series for new art subscribers",
  status: :draft,
  trigger_type: :form_submission
)

EmailSequenceStep.create!(email_sequence: mclc_seq, position: 1, delay_hours: 0, subject: "Welcome to MCLC Studios", body_html: "<p>Thanks for following along. Here is what to expect.</p>", settings: {})
EmailSequenceStep.create!(email_sequence: mclc_seq, position: 2, delay_hours: 120, subject: "The story behind the work", body_html: "<p>A look at Megans process and inspiration.</p>", settings: {})

mclc_campaign = Campaign.create!(
  account: account,
  name: "New Collection Drop",
  subject: "New work just dropped",
  from_name: "MCLC Studios",
  from_email: "hello@mclcstudios.com",
  body_html: "<p>New pieces are now available in the studio.</p>",
  status: :draft,
  campaign_type: :regular,
  settings: { "brand" => "mclc-studios" }
)

puts "MCLC List: #{mclc_list.id}"
puts "MCLC Form: #{mclc_form.id}"
puts "MCLC Sequence: #{mclc_seq.id}"
puts "MCLC Campaign: #{mclc_campaign.id}"
puts "Done!"
