AdminUser.delete_all
User.delete_all

# Create admin for development environment (only if it doesn't already exist)
if Rails.env.development?
  AdminUser.find_or_create_by(email: 'admin@example.com') do |admin|
    admin.password = 'password'
    admin.password_confirmation = 'password'
  end
end

# Create admin for production environment (only if it doesn't already exist)
if Rails.env.production?
  AdminUser.find_or_create_by(email: 'admin@example.com') do |admin|
    admin.password = 'password'
    admin.password_confirmation = 'password'
  end
end



User.create!(
  name: 'Test User',
  email: 'user@example.com',
  password: 'password',
  mobile_number: '1234567890',
  role: 'user'
)

User.create!(
  name: 'Test Supervisor',
  email: 'supervisor@example.com',
  password: 'password',
  mobile_number: '0987654321',
  role: 'supervisor'
)