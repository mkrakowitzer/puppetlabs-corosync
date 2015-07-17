require 'spec_helper'

describe Puppet::Type.type(:cs_colocation).provider(:pcs) do
  before do
    described_class.stubs(:command).with(:pcs).returns 'pcs'
  end

  context 'when getting instances' do
    let :instances do

      test_cib = <<-EOS
      <cib>
      <configuration>
        <constraints>
          <rsc_colocation id="first_with_second" rsc="first" score="INFINITY" with-rsc="second"/>
        </constraints>
      </configuration>
      </cib>
      EOS

      described_class.expects(:block_until_ready).returns(nil)
      if Puppet::PUPPETVERSION.to_f < 3.4
        Puppet::Util::SUIDManager.expects(:run_and_capture).with(['pcs', 'cluster', 'cib']).at_least_once.returns([test_cib, 0])
      else
        Puppet::Util::Execution.expects(:execute).with(['pcs', 'cluster', 'cib'], {:failonfail => true}).at_least_once.returns(
          Puppet::Util::Execution::ProcessOutput.new(test_cib, 0)
        )
      end
      instances = described_class.instances
    end

    it 'should have an instance for each <colocation>' do
      expect(instances.count).to eq(1)
    end

    describe 'each instance' do
      let :instance do
        instances.first
      end

      it "is a kind of #{described_class.name}" do
        expect(instance).to be_a_kind_of(described_class)
      end

      it "is named by the <primitive>'s id attribute" do
        expect(instance.name).to eq("first_with_second")
      end

      it "should have attributes" do
        expect(instance.primitives).to eq(['second', 'first'])
        expect(instance.score).to eq('INFINITY')
      end
    end
  end

  context 'when flushing' do
    def expect_update(pattern)
      if Puppet::PUPPETVERSION.to_f < 3.4
        Puppet::Util::SUIDManager.expects(:run_and_capture).with { |*args|
          cmdline=args[0].join(" ")
          expect(cmdline).to match(pattern)
          true
        }.at_least_once.returns(['', 0])
      else
        Puppet::Util::Execution.expects(:execute).with{ |*args|
          cmdline=args[0].join(" ")
          expect(cmdline).to match(pattern)
          true
        }.at_least_once.returns(
          Puppet::Util::Execution::ProcessOutput.new('', 0)
        )
      end
    end
  
    context 'with 2 primitives' do 
      let :resource do
        Puppet::Type.type(:cs_colocation).new(
           :name => 'first_with_second',
           :provider => :crm,
           :primitives => [ 'first', 'second' ],
           :ensure => :present)
      end
  
      let :instance do
        instance = described_class.new(resource)
        instance.create
        instance
      end
  
      it 'creates colocation with defaults' do
         expect_update(/pcs constraint colocation add first with second INFINITY id=first_with_second/)
         instance.flush
      end
  
      it 'updates first primitive' do
        instance.primitives = [ 'first_updated', 'second' ]
        expect_update(/pcs constraint colocation add first_updated with second INFINITY id=first_with_second/)
        instance.flush
      end
  
      it 'updates second primitive' do
        instance.primitives = [ 'first', 'second_updated' ]
        expect_update(/pcs constraint colocation add first with second_updated INFINITY id=first_with_second/)
        instance.flush
      end
  
      it 'updates both primitives' do
        instance.primitives = [ 'first_updated', 'second_updated' ]
        expect_update(/pcs constraint colocation add first_updated with second_updated INFINITY id=first_with_second/)
        instance.flush
      end
  
      it 'sets score' do
        instance.score = '-INFINITY'
        expect_update(/pcs constraint colocation add first with second -INFINITY id=first_with_second/)
        instance.flush
      end
    end
  end
end
