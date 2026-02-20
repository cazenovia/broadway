# Ensure we have our default Field Worker
# find_or_create_by ensures this is safe to run multiple times!
User.find_or_create_by!(email: "worker@broadway.app") do |user|
  user.name = "Field Worker 1"
end