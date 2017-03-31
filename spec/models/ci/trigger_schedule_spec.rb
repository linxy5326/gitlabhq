require 'spec_helper'

describe Ci::TriggerSchedule, models: true do

  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:trigger) }
  # it { is_expected.to validate_presence_of :cron }
  # it { is_expected.to validate_presence_of :cron_time_zone }
  it { is_expected.to respond_to :ref }

  it 'should validate less_than_1_hour_from_now' do
    trigger_schedule = create(:ci_trigger_schedule, :cron_nightly_build)
    trigger_schedule.cron = '* * * * *'
    trigger_schedule.valid?
    expect(trigger_schedule.errors[:cron].first).to include('can not be less than 1 hour')
  end

  describe '#schedule_next_run!' do
    context 'when more_than_1_hour_from_now' do
      let(:trigger_schedule) { create(:ci_trigger_schedule, :cron_nightly_build) }

      before do
        trigger_schedule.schedule_next_run!
      end

      it 'updates next_run_at' do
        next_time = Ci::CronParser.new(trigger_schedule.cron, trigger_schedule.cron_time_zone).next_time_from(Time.now)
        expect(Ci::TriggerSchedule.last.next_run_at).to eq(next_time)
      end
    end
  end

  describe '#real_next_run' do
    subject { trigger_schedule.real_next_run(worker_cron: worker_cron, worker_time_zone: worker_time_zone) }

    context 'when next_run_at > worker_next_time' do
      let(:worker_cron) { '0 */12 * * *' } # each 00:00, 12:00
      let(:worker_time_zone) { 'UTC' }
      let(:trigger_schedule) { create(:ci_trigger_schedule, :cron_weekly_build, cron_time_zone: user_time_zone, trigger: trigger) }

      context 'when user is in Europe/London(+00:00)' do
        let(:user_time_zone) { 'Europe/London' }

        it 'returns next_run_at' do
          is_expected.to eq(trigger_schedule.next_run_at)
        end
      end

      context 'when user is in Asia/Hong_Kong(+08:00)' do
        let(:user_time_zone) { 'Asia/Hong_Kong' }

        it 'returns next_run_at' do
          is_expected.to eq(trigger_schedule.next_run_at)
        end
      end

      context 'when user is in Canada/Pacific(-08:00)' do
        let(:user_time_zone) { 'Canada/Pacific' }

        it 'returns next_run_at' do
          is_expected.to eq(trigger_schedule.next_run_at)
        end
      end
    end

    context 'when worker_next_time > next_run_at' do
      let(:worker_cron) { '0 0 */2 * *' } # every 2 days
      let(:worker_time_zone) { 'UTC' }
      let(:trigger_schedule) { create(:ci_trigger_schedule, :cron_nightly_build, cron_time_zone: user_time_zone, trigger: trigger) }

      context 'when user is in Europe/London(+00:00)' do
        let(:user_time_zone) { 'Europe/London' }

        it 'returns worker_next_time' do
          is_expected.to eq(Ci::CronParser.new(worker_cron, worker_time_zone).next_time_from_now)
        end
      end

      context 'when user is in Asia/Hong_Kong(+08:00)' do
        let(:user_time_zone) { 'Asia/Hong_Kong' }

        it 'returns worker_next_time' do
          is_expected.to eq(Ci::CronParser.new(worker_cron, worker_time_zone).next_time_from_now)
        end
      end

      context 'when user is in Canada/Pacific(-08:00)' do
        let(:user_time_zone) { 'Canada/Pacific' }

        it 'returns worker_next_time' do
          is_expected.to eq(Ci::CronParser.new(worker_cron, worker_time_zone).next_time_from_now)
        end
      end
    end
  end
end
