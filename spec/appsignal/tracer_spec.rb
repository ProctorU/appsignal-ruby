require 'spec_helper'

class Job
  include Appsignal::Tracer

  def perform
    puts 'The job is performing'
  end

  def generate_error
    raise 'This generated an error'
  end

  appsignal_tracer_for(:perform)
end

describe Appsignal::Tracer do
  let(:job) { Job.new }
  subject { job }

  context "tracer_for" do
    it { should respond_to :appsignal_trace_perform }
    it { should respond_to :appsignal_perform_trace_perform }
    it { should respond_to :perform }
  end

  context "when inactive" do
    before do
      Appsignal.stub!(:active => false)
      class Jobless
        include Appsignal::Tracer

        def perform
          puts 'The job is performing'
        end

        appsignal_tracer_for(:perform)
      end
    end
    let(:job) { Jobless.new }

    it { should_not respond_to :appsignal_trace_perform }
    it { should_not respond_to :appsignal_perform_trace_perform }
    it { should respond_to :perform }
  end

  context "perform_trace" do
    let(:transaction) { Appsignal::Transaction.create('background_1', 'env') }

    before do
      transaction
      Appsignal::Transaction.should_receive(:create).
        and_return(transaction)
      transaction.should_receive(:complete_trace!)
    end

    it "should send a trace of a method" do
      transaction.should_receive(:set_log_entry)
      job.appsignal_perform_trace('count') do
        1 + 1
      end
    end

    it "should send a trace of an exception" do
      transaction.should_receive(:add_exception)
      expect {
        job.appsignal_perform_trace('count') do
          raise ArgumentError, 'Count error'
        end
      }.to raise_error ArgumentError
    end
  end

  context "hashes" do

    it "should generate log_entry" do
      start_time = Time.parse("01-01-2012 00:00:00 +0000")
      end_time = Time.parse("01-01-2012 00:00:10 +0000")
      job.send(:appsignal_log_entry, 'perform',
        start_time,
        end_time
      ).should == {
        :action => "Job#perform",
        :duration => 10000.0,
        :time => 1325376000.0,
        :end => 1325376010.0,
        :kind => "background"
      }
    end

    it "should generate exception" do
      job.send(:appsignal_exception, Exception.new('Error'), 'generate_error'
      ).should == {
        :exception => {
          :backtrace => nil,
          :exception => "Exception",
          :message => "Error"
        }
      }
    end
  end
end