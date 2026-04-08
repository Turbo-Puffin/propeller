account = Account.create!(
  name: "Turbo Puffin",
  subdomain: "turbopuffin",
  plan: :pro,
  status: :active,
  settings: {}
)

user = User.create!(
  account: account,
  email: "matthew@turbopuffin.com",
  name: "Matthew Crist",
  password: "propeller2026!",
  password_confirmation: "propeller2026!",
  role: :owner,
  confirmed_at: Time.current
)

puts "Account: #{account.id} (#{account.name}, #{account.plan})"
puts "User: #{user.id} (#{user.email})"

# --- Constraint Advantage ---
ca_list = ContactList.create!(account: account, name: "The Constraint Advantage", description: "Book launch email list - nurture sequences for pre-launch interest")

ca_form = Form.create!(
  account: account,
  name: "Constraint Advantage Landing Page",
  form_type: :landing_page,
  status: :active,
  success_message: "You are on the list! We will notify you when The Constraint Advantage launches.",
  settings: { "brand" => "constraint-advantage", "domain" => "constraintadvantage.com" }
)

ca_seq = EmailSequence.create!(
  account: account,
  name: "Constraint Advantage Welcome Series",
  description: "5-part nurture sequence for book pre-launch signups",
  status: :draft,
  trigger_type: :form_submission
)

EmailSequenceStep.create!(email_sequence: ca_seq, position: 1, delay_hours: 0, subject: "Welcome - The Constraint Advantage", body_html: "<p>Thanks for signing up. The book is coming soon.</p>", settings: {})
EmailSequenceStep.create!(email_sequence: ca_seq, position: 2, delay_hours: 72, subject: "Why constraints are your superpower", body_html: "<p>Preview of Chapter 1 themes.</p>", settings: {})
EmailSequenceStep.create!(email_sequence: ca_seq, position: 3, delay_hours: 168, subject: "The two-person advantage", body_html: "<p>How small teams outperform large ones.</p>", settings: {})

ca_campaign = Campaign.create!(
  account: account,
  name: "Book Launch Announcement",
  subject: "The Constraint Advantage is here",
  from_name: "Matthew Crist",
  from_email: "matthew@constraintadvantage.com",
  body_html: "<p>The book is live. Get your copy.</p>",
  status: :draft,
  campaign_type: :regular,
  settings: { "brand" => "constraint-advantage" }
)

puts "CA List: #{ca_list.id}"
puts "CA Form: #{ca_form.id}"
puts "CA Sequence: #{ca_seq.id} (#{ca_seq.steps.count} steps)"
puts "CA Campaign: #{ca_campaign.id}"

# --- MCLC Studios ---
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
puts "MCLC Sequence: #{mclc_seq.id} (#{mclc_seq.steps.count} steps)"
puts "MCLC Campaign: #{mclc_campaign.id}"
puts "Done!"
