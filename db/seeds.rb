# Ensure we have our default Field Worker
# find_or_create_by ensures this is safe to run multiple times!
User.find_or_create_by!(email_address: "baltimoretim@gmail.com") do |user|
  user.name = "Tim Durkin"
  user.password = "Magik26!"
end