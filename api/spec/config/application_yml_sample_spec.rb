require "rails_helper"
require "yaml"

RSpec.describe "application.yml.sample config sanity (regression test for BUG-003)" do
  let(:sample_config) do
    YAML.load_file(Rails.root.join("config", "application.yml.sample"))
  end

  it "points APP_BASE_URL to the frontend (5173), not the backend API (3001)" do
    expect(sample_config["APP_BASE_URL"]).to eq("http://localhost:5173")
  end
end