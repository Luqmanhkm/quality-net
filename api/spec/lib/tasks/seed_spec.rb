require "rails_helper"

RSpec.describe "db:seed" do
  def run_seed
    load Rails.root.join("db", "seeds.rb")
  end

  it "creates exactly one default user for local login (regression test for BUG-002)" do
    expect { run_seed }.to change { User.count }.by(1)

    admin = User.find_by(email: "admin@test-corp.local")
    expect(admin).to be_present
    expect(admin.role).to eq("admin")
  end

  it "is idempotent — running seed twice does not create duplicate users" do
    run_seed
    expect { run_seed }.not_to change { User.count }
  end
end