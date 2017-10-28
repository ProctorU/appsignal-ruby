if DependencyHelper.que_present?
  describe "Que integration" do
    before(:context) do
      require "que"

      class MyQueJob < Que::Job
        def run
        end
      end
    end

    before do
      start_agent
      allow(Que).to receive(:execute)
    end

    let(:job_attrs) do
      {
        :job_id => 123,
        :queue => "dfl",
        :job_class => "MyQueJob",
        :priority => 100,
        :args => ["the floor"],
        :run_at => fixed_time,
        :error_count => 0
      }
    end

    describe :around__run_que_plugin do
      let(:env) do
        {
          :class => "MyQueJob",
          :method => "run",
          :metadata => {
            :id => 123,
            :queue => "dfl",
            :priority => 100,
            :run_at => fixed_time.to_s,
            :attempts => 0
          },
          :params => ["the floor"]
        }
      end
      let(:request) { Appsignal::Transaction::GenericRequest.new(env) }
      let(:transaction) do
        Appsignal::Transaction.new(
          SecureRandom.uuid,
          Appsignal::Transaction::BACKGROUND_JOB,
          request
        )
      end
      let(:job) { MyQueJob.new(job_attrs) }

      before do
        allow(transaction).to receive(:complete).and_return(true)
        allow(Appsignal::Transaction).to receive(:current).and_return(transaction)
      end

      context "without exception" do
        it "should create a GenericRequest with the correct params" do
          expect(Appsignal::Transaction::GenericRequest).to receive(:new)
            .with(env)
            .and_return(request)
        end

        it "should create a new transaction" do
          allow(Appsignal::Transaction::GenericRequest).to receive(:new).and_return(request)
          expect(Appsignal::Transaction).to receive(:create)
            .with(instance_of(String), Appsignal::Transaction::BACKGROUND_JOB, request)
            .and_return(transaction)
        end

        it "should call Appsignal#instrument with the correct params" do
          expect(Appsignal).to receive(:instrument).with("perform_job.que")
        end

        it "should close the transaction" do
          expect(transaction).to receive(:complete)
        end

        after { job._run }
      end

      context "with exception" do
        let(:job) { ::MyQueJob.new(job_attrs) }
        let(:error) { ::StandardError.new("TestError") }

        before do
          allow(job).to receive(:run).and_raise(error)
          allow(Appsignal::Transaction).to receive(:current).and_return(transaction)
          expect(Appsignal::Transaction).to receive(:create)
            .with(
              kind_of(String),
              Appsignal::Transaction::BACKGROUND_JOB,
              kind_of(Appsignal::Transaction::GenericRequest)
            ).and_return(transaction)
        end

        it "should set the exception" do
          expect(transaction).to receive(:set_error).with(error)
        end

        after { job._run }
      end
    end
  end
end
