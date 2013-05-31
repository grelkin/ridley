require 'spec_helper'

describe Ridley::NodeResource do
  let(:host) { "33.33.33.10" }
  let(:worker) { double('worker', alive?: true, terminate: nil) }
  let(:host_commander) { double('host-commander') }
  let(:secret) { "super_secret" }
  let(:instance) do
    inst = described_class.new(double, encrypted_data_bag_secret: secret)
    inst.stub(connection: chef_zero_connection, host_commander: host_commander)
    inst
  end

  describe "#bootstrap" do
    let(:hosts) { [ "192.168.1.2" ] }
    let(:options) do
      {
        validator_path: fixtures_path.join("reset.pem").to_s,
        encrypted_data_bag_secret: File.read(fixtures_path.join("reset.pem"))
      }
    end
    let(:bootstrapper) { double('bootstrapper', run: nil) }
    subject { instance }
    before { Ridley::Bootstrapper.should_receive(:new).with(hosts, anything).and_return(bootstrapper) }

    it "runs the Bootstrapper" do
      bootstrapper.should_receive(:run)

      subject.bootstrap("192.168.1.2", options)
    end
  end

  describe "#chef_run" do
    it "sends the message #chef_client to the instance's host_commander" do
      host_commander.should_receive(:chef_client).with(host, ssh: instance.ssh, winrm: instance.winrm)
      instance.chef_run(host)
    end
  end

  describe "#put_secret" do
    it "sends the message #put_secret to the instance's host_commander" do
      host_commander.should_receive(:put_secret).with(host, secret, ssh: instance.ssh, winrm: instance.winrm)
      instance.put_secret(host)
    end
  end

  describe "#ruby_script" do
    let(:command_lines) { ["puts 'hello'", "puts 'there'"] }

    it "sends the message #ruby_script to the instance's host_commander" do
      host_commander.should_receive(:ruby_script).with(host, command_lines, ssh: instance.ssh, winrm: instance.winrm)
      instance.ruby_script(host, command_lines)
    end
  end

  describe "#execute_command" do
    let(:command) { "echo 'hello world'" }

    it "sends the message #run to the instance's host_commander" do
      host_commander.should_receive(:run).with(host, command, ssh: instance.ssh, winrm: instance.winrm)
      instance.execute_command(host, command)
    end
  end

  describe "#merge_data" do
    let(:node_name) { "rspec-test" }
    let(:run_list) { [ "recipe[one]", "recipe[two]" ] }
    let(:attributes) { { deep: { two: "val" } } }

    subject(:result) { instance.merge_data(node_name, run_list: run_list, attributes: attributes) }

    context "when a node of the given name exists" do
      before do
        chef_node(node_name,
          run_list: [ "recipe[one]", "recipe[three]" ],
          normal: { deep: { one: "val" } }
        )
      end

      it "returns a Ridley::NodeObject" do
        expect(result).to be_a(Ridley::NodeObject)
      end

      it "has a union between the run list of the original node and the new run list" do
        expect(result.run_list).to eql(["recipe[one]","recipe[three]","recipe[two]"])
      end

      it "has a deep merge between the attributes of the original node and the new attributes" do
        expect(result.normal.to_hash).to eql(deep: { one: "val", two: "val" })
      end
    end

    context "when a node with the given name does not exist" do
      let(:node_name) { "does_not_exist" }

      it "raises a ResourceNotFound error" do
        expect { result }.to raise_error(Ridley::Errors::ResourceNotFound)
      end
    end
  end
end
