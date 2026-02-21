# Development seeds — create test users and a sample conversation
return unless Rails.env.development?

puts "Seeding database..."

alice = User.find_or_create_by!(email: "alice@example.com") do |u|
  u.display_name    = "Alice Silva"
  u.nickname        = "alice"
  u.password        = "password123"
  u.password_confirmation = "password123"
  u.phone           = "+55 11 91111-1111"
  u.bio             = "Olá! Estou usando o Chat."
  u.jti             = SecureRandom.uuid
end
alice.update_column(:nickname, "alice") if alice.nickname.blank?

bob = User.find_or_create_by!(email: "bob@example.com") do |u|
  u.display_name    = "Bob Santos"
  u.nickname        = "bob"
  u.password        = "password123"
  u.password_confirmation = "password123"
  u.phone           = "+55 11 92222-2222"
  u.jti             = SecureRandom.uuid
end
bob.update_column(:nickname, "bob") if bob.nickname.blank?

carol = User.find_or_create_by!(email: "carol@example.com") do |u|
  u.display_name    = "Carol Oliveira"
  u.nickname        = "carol"
  u.password        = "password123"
  u.password_confirmation = "password123"
  u.jti             = SecureRandom.uuid
end
carol.update_column(:nickname, "carol") if carol.nickname.blank?

convo = Conversation.find_or_create_direct(alice, bob)

if convo.messages.empty?
  convo.messages.create!(sender: alice, content: "Oi Bob! Como você está?",    message_type: :text)
  convo.messages.create!(sender: bob,   content: "Olá Alice! Tudo ótimo! 😄", message_type: :text)
  convo.messages.create!(sender: alice, content: "Que bom! Vamos usar esse chat novo?", message_type: :text)
end

group = Conversation.find_by(name: "Grupo Dev")
group ||= Conversation.create!(name: "Grupo Dev", conversation_type: :group, description: "Grupo de desenvolvedores").tap do |g|
  g.participants.create!(user: alice, role: :admin)
  g.participants.create!(user: bob,   role: :member)
  g.participants.create!(user: carol, role: :member)
end

if group.messages.empty?
  group.messages.create!(sender: alice, content: "Bem-vindos ao Grupo Dev! 🚀", message_type: :text)
end

Template.find_or_create_by!(name: "Boas-vindas") do |t|
  t.category   = "general"
  t.content    = "Olá {{nome}}! Seja muito bem-vindo(a) ao nosso serviço. Estamos felizes em tê-lo(a) conosco!"
  t.variables  = [ "nome" ]
  t.created_by = alice
end

Template.find_or_create_by!(name: "Suporte - Confirmação") do |t|
  t.category   = "support"
  t.content    = "Olá {{nome}}, recebemos seu chamado #{{ticket}}. Nossa equipe entrará em contato em até {{prazo}}."
  t.variables  = [ "nome", "ticket", "prazo" ]
  t.created_by = alice
end

puts "✅ Seeds concluídos!"
puts "   alice@example.com / password123"
puts "   bob@example.com   / password123"
puts "   carol@example.com / password123"
