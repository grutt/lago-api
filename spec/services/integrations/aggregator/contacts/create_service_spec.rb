# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Integrations::Aggregator::Contacts::CreateService do
  subject(:service_call) { described_class.call(integration:, customer:, subsidiary_id:) }

  let(:customer) { create(:customer, organization:) }
  let(:subsidiary_id) { '1' }
  let(:organization) { create(:organization) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/#{integration_type}/contacts" }

  let(:headers) do
    {
      'Connection-Id' => integration.connection_id,
      'Authorization' => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
      'Provider-Config-Key' => integration_type
    }
  end

  before do
    allow(LagoHttpClient::Client).to receive(:new).with(endpoint).and_return(lago_client)
  end

  describe '#call' do
    context 'when service call is successful' do
      let(:response) { instance_double(Net::HTTPOK) }

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_return(response)
        allow(response).to receive(:body).and_return(body)
      end

      context 'when response is a string' do
        let(:integration) { create(:netsuite_integration, organization:) }
        let(:integration_type) { 'netsuite' }

        let(:params) do
          {
            'type' => 'customer',
            'isDynamic' => false,
            'columns' => {
              'companyname' => customer.name,
              'subsidiary' => subsidiary_id,
              'custentity_lago_id' => customer.id,
              'custentity_lago_sf_id' => customer.external_salesforce_id,
              'custentity_form_activeprospect_customer' => customer.name,
              'email' => customer.email,
              'phone' => customer.phone
            },
            'options' => {
              'ignoreMandatoryFields' => false
            }
          }
        end

        let(:body) do
          path = Rails.root.join('spec/fixtures/integration_aggregator/contacts/success_string_response.json')
          File.read(path)
        end

        it 'returns contact id' do
          result = service_call

          aggregate_failures do
            expect(result).to be_success
            expect(result.contact_id).to eq('1')
          end
        end

        it 'delivers a success webhook' do
          expect { service_call }.to enqueue_job(SendWebhookJob)
            .with(
              'customer.accounting_provider_created',
              customer
            ).on_queue(:webhook)
        end
      end

      context 'when response is a hash' do
        let(:integration) { create(:xero_integration, organization:) }
        let(:integration_type) { 'xero' }

        let(:params) do
          [
            {
              'name' => customer.name,
              'email' => customer.email,
              'city' => customer.city,
              'zip' => customer.zipcode,
              'country' => customer.country,
              'state' => customer.state,
              'phone' => customer.phone
            }
          ]
        end

        context 'when contact is succesfully created' do
          let(:body) do
            path = Rails.root.join('spec/fixtures/integration_aggregator/contacts/success_hash_response.json')
            File.read(path)
          end

          it 'returns contact id' do
            result = service_call

            aggregate_failures do
              expect(result).to be_success
              expect(result.contact_id).to eq('2e50c200-9a54-4a66-b241-1e75fb87373f')
            end
          end

          it 'delivers a success webhook' do
            expect { service_call }.to enqueue_job(SendWebhookJob)
              .with(
                'customer.accounting_provider_created',
                customer
              ).on_queue(:webhook)
          end
        end

        context 'when contact is not created' do
          let(:body) do
            path = Rails.root.join('spec/fixtures/integration_aggregator/contacts/failure_hash_response.json')
            File.read(path)
          end

          it 'does not return contact id' do
            result = service_call

            aggregate_failures do
              expect(result).to be_success
              expect(result.contact).to be(nil)
            end
          end

          it 'does not create integration resource object' do
            expect { service_call }.not_to change(IntegrationResource, :count)
          end
        end
      end
    end

    context 'when service call is not successful' do
      let(:integration) { create(:netsuite_integration, organization:) }
      let(:integration_type) { 'netsuite' }

      let(:params) do
        {
          'type' => 'customer',
          'isDynamic' => false,
          'columns' => {
            'companyname' => customer.name,
            'subsidiary' => subsidiary_id,
            'custentity_lago_id' => customer.id,
            'custentity_lago_sf_id' => customer.external_salesforce_id,
            'custentity_form_activeprospect_customer' => customer.name,
            'email' => customer.email,
            'phone' => customer.phone
          },
          'options' => {
            'ignoreMandatoryFields' => false
          }
        }
      end

      let(:body) do
        path = Rails.root.join('spec/fixtures/integration_aggregator/error_response.json')
        File.read(path)
      end

      let(:http_error) { LagoHttpClient::HttpError.new(500, body, nil) }

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_raise(http_error)
      end

      it 'returns an error' do
        result = service_call

        aggregate_failures do
          expect(result).not_to be_success
          expect(result.error.code).to eq('action_script_runtime_error')
          expect(result.error.message)
            .to eq('action_script_runtime_error: submitFields: Missing a required argument: type')
        end
      end

      it 'delivers an error webhook' do
        expect { service_call }.to enqueue_job(SendWebhookJob)
          .with(
            'customer.accounting_provider_error',
            customer,
            provider: 'netsuite',
            provider_code: integration.code,
            provider_error: {
              message: 'submitFields: Missing a required argument: type',
              error_code: 'action_script_runtime_error'
            }
          )
      end
    end
  end
end
