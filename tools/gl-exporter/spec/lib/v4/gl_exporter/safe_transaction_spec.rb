require "spec_helper"

describe GlExporter::SafeTransaction, :v4 do
  subject(:transaction) { described_class.new(logger) }
  subject(:logger) { NullLogger.new }

  describe "#safely" do
    it "reraises an exception for an unhandled error" do
       e = FakeError.new
       expect do
         transaction.safely { raise e }
       end.to raise_error(e)
    end

    it "does not raise an exception for a known error" do
       e = Rugged::OdbError.new
       expect do
         transaction.safely { raise e }
       end.to_not raise_error
    end

    it "logs errors to the provided logger for known errors" do
      e = Rugged::OdbError.new
      expect(logger).to receive(:error)
      transaction.safely { raise e }
    end

    it "maintains proper scope" do
      a = 1
      transaction.safely { a = a + 1 }
      expect(a).to eq(2)
    end

    it "returns the instance of the transaction" do
      result = transaction.safely { 1 + 1 }
      expect(result).to eq(transaction)
    end

    context "when provided an error class name" do
      it "can handle that error" do
        e = FakeError.new
        expect do
          transaction.safely("FakeError") { raise e }
        end.to_not raise_error
      end
    end

    context "when provided an array of error class names" do
      it "can handle all of those errors" do
        e = FakeError.new
        expect do
          transaction.safely(["FakeError"]) { raise e }
        end.to_not raise_error
      end
    end
  end

  describe "#error" do
    let(:test_object) { double }

    it "calls the block if a handled exception is caught" do
      expect(test_object).to receive(:to_s)
      e = Rugged::OdbError.new
      transaction.safely {
        raise e
      }.error {
        test_object.to_s
      }
    end

    it "does not call the block if no exception is caught" do
      expect(test_object).to_not receive(:to_s)
      transaction.safely {
        1 + 1
      }.error {
        test_object.to_s
      }
    end

    it "passes back the error object" do
      e = Rugged::OdbError.new
      transaction.safely {
        raise e
      }.error { |err|
        expect(err).to eq(e)
      }
    end

    it "does nothing when called without #safely" do
      expect(test_object).to_not receive(:to_s)
      transaction.error { test_object.to_s }
    end

    it "returns the safe transaction instance" do
      result = transaction.safely { raise Rugged::OdbError.new }.error { 1 + 1 }
      expect(result).to eq(transaction)
    end
  end

  describe "#success" do
    let(:test_object) { double }

    it "does not call the block if a handled exception is caught" do
      expect(test_object).to_not receive(:to_s)
      e = Rugged::OdbError.new
      transaction.safely {
        raise e
      }.success {
        test_object.to_s
      }
    end

    it "calls the block if no exception is caught" do
      expect(test_object).to receive(:to_s)
      transaction.safely {
        1 + 1
      }.success {
        test_object.to_s
      }
    end

    it "does nothing when called without #safely" do
      expect(test_object).to_not receive(:to_s)
      transaction.success { test_object.to_s }
    end

    it "returns the safe transaction instance" do
      result = transaction.safely {}.success { 1 + 1 }
      expect(result).to eq(transaction)
    end
  end

  describe "#response" do
    it "returns the result of the safely executed code" do
      result = transaction.safely { 1 + 1 }.response
      expect(result).to eq(2)
    end
  end

  context "with the helper included" do
    let(:test_object) { PseudoModel.new }

    before do
      PseudoModel.include(GlExporter::SafeExecution)
      PseudoModel.log_handled_exceptions_to(:logger)
      allow_any_instance_of(PseudoModel).to receive(:logger).and_return(logger)
    end

    describe "#safely" do
      it "runs the command against a new instance of SafeTransaction" do
        expect_any_instance_of(GlExporter::SafeTransaction).to receive(:safely)
        test_object.instance_eval do
          safely { 1 + 1 }
        end
      end

      it "returns a SafeTransaction instance" do
        result = test_object.instance_eval do
          safely { 1 + 1 }
        end
        expect(result).to be_a(GlExporter::SafeTransaction)
      end

      context "when provided an error class name" do
        it "can handle that error" do
          e = FakeError.new
          expect do
            test_object.instance_eval do
              safely("FakeError") { raise e }
            end
          end.to_not raise_error
        end
      end
    end
  end
end

class FakeError < StandardError; end
