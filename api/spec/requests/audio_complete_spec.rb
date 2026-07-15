require "rails_helper"

RSpec.describe "POST /api/v1/sessions/:token/audio_complete", type: :request do
  let(:user) { User.create!(email: "assessor@spec.local", password: "password123", role: "admin") }

  let(:assessment) do
    Assessment.create!(
      tenant_id: 1,
      created_by: user.id,
      name: "Spec Assessment",
      time_limit_min: 45
    )
  end

  let(:session_record) do
    Session.create!(
      tenant_id: 1,
      assessment_id: assessment.id,
      status: "active",
      started_at: Time.current
    )
  end

  it "ends the session with reason all_covered by default (normal completion path)" do
    post "/api/v1/sessions/#{session_record.invite_token}/audio_complete"

    expect(response).to have_http_status(:ok)
    session_record.reload
    expect(session_record.status).to eq("ended")
    expect(session_record.end_reason).to eq("all_covered")
  end

  it "ends the session with reason error when explicitly passed (regression test for BUG-006)" do
    post "/api/v1/sessions/#{session_record.invite_token}/audio_complete", params: { reason: "error" }

    expect(response).to have_http_status(:ok)
    session_record.reload
    expect(session_record.status).to eq("ended")
    expect(session_record.end_reason).to eq("error")
  end

  it "falls back to all_covered if an invalid reason is passed" do
    post "/api/v1/sessions/#{session_record.invite_token}/audio_complete", params: { reason: "not_a_real_reason" }

    expect(response).to have_http_status(:ok)
    session_record.reload
    expect(session_record.end_reason).to eq("all_covered")
  end

  it "is idempotent — calling it again after the session already ended does not error" do
    post "/api/v1/sessions/#{session_record.invite_token}/audio_complete", params: { reason: "error" }
    post "/api/v1/sessions/#{session_record.invite_token}/audio_complete", params: { reason: "error" }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["message"]).to eq("Session already ended")
  end

  it "returns 404 for an invalid invite token" do
    post "/api/v1/sessions/nonexistent-token/audio_complete"

    expect(response).to have_http_status(:not_found)
  end
end