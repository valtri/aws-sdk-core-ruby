require 'spec_helper'

module Aws
  module Resources
    describe Definition do

      describe '#define_service' do

        let(:config) { double('config', api: api) }

        let(:client_class) { Aws::Client.define('Client', api: api) }

        let(:client) { double('client', config:config) }

        let(:definition) {{
          'service' => {},
          'resources' => {},
        }}

        let(:shapes) {{}}

        let(:api) { Seahorse::Model::Api.new('shapes' => shapes) }

        let(:namespace) { Module.new }

        before(:each) do
          namespace.const_set(:Client, client_class)
          client_class.paginators = Paging::NullProvider.new
          allow(client_class).to receive(:new).and_return(client)
        end

        def apply_definition
          Definition.new(definition).apply(namespace)
        end

        describe 'service' do

          it 'constructs default clients' do
            Definition.new(definition).apply(namespace)
            expect(namespace::Resource.new.client).to be(client)
          end

          it 'defines a resource class for each named resource' do
            definition['resources'] = {
              'Group' => { 'identifiers' => [{ 'name' => 'Id' }] },
              'User' => { 'identifiers' => [{ 'name' => 'Name' }] },
            }

            apply_definition

            expect(namespace.constants.sort).to eq(
              [:Client, :Group, :Resource, :User])

            svc = namespace::Resource.new
            expect(svc).to be_kind_of(Resource)
            expect(svc.identifiers).to eq({})

            user = namespace::User.new(name:'user-name')
            expect(user).to be_kind_of(Resource)
            expect(user.identifiers).to eq(name:'user-name')

            group = namespace::Group.new(id:'group-id')
            expect(group).to be_kind_of(Resource)
            expect(group.identifiers).to eq(id:'group-id')
          end

          describe 'actions' do

            it 'supports basic operations' do
              definition['service'] = {
                'actions' => {
                  'DoSomething' => {
                    'request' => {
                      'operation' => 'ClientMethod'
                    }
                  }
                }
              }

              client_response = double('client-response')
              expect(client).to receive(:client_method).
                with(foo:'bar').
                and_return(client_response)

              apply_definition

              resp = namespace::Resource.new.do_something(foo:'bar')
              expect(resp).to be(client_response)
            end

            it 'supports operations that extract data' do
              definition['service'] = {
                'actions' => {
                  'DoSomething' => {
                    'request' => {
                      'operation' => 'ClientMethod'
                    },
                    'path' => 'Nested.Value'
                  }
                }
              }

              expect(client).to receive(:client_method).
                and_return(double('client-response',
                  data: { 'nested' => { 'value' => 'nested-value' }}
                ))

              apply_definition

              resp = namespace::Resource.new.do_something(foo:'bar')
              expect(resp).to eq('nested-value')
            end

            it 'supports operations that return singular resources' do
              definition.update(
                'service' => {
                  'actions' => {
                    'CreateThing' => {
                      'request' => {
                        'operation' => 'MakeThing'
                      },
                      'resource' => {
                        'type' => 'Thing',
                        'identifiers' => [
                          {
                            'target' => 'Name',
                            'sourceType' => 'requestParameter',
                            'source' => 'ThingName'
                          }
                        ]
                      }
                    }
                  }
                },
                'resources' => {
                  'Thing' => {
                    'identifiers' => [{ 'name' => 'Name' }]
                  }
                }
              )

              expect(client).to receive(:make_thing).
                with(thing_name:'thing-name') do |params|
                  double('client-response',
                    context: double('request-context', params:params))
                end

              apply_definition

              svc = namespace::Resource.new
              thing = svc.create_thing(thing_name:'thing-name')
              expect(thing).to be_kind_of(namespace::Thing)
              expect(thing.client).to be(svc.client)
              expect(thing.name).to eq('thing-name')
            end

            it 'accepts identifier names in place of request params' do
              # For this test case to work, request params must be renamed
              # following the resource identifier sources.  In this example
              # the "MakeThing" request requires a "ThingName" param, and
              # we want the user to be able to specify "Name" (the idenitifer
              # target) or "ThingName" (the request param).
              pending('not implemented')
              definition.update(
                'service' => {
                  'actions' => {
                    'CreateThing' => {
                      'request' => {
                        'operation' => 'MakeThing'
                      },
                      'resource' => {
                        'type' => 'Thing',
                        'identifiers' => [
                          {
                            'target' => 'Name',
                            'sourceType' => 'requestParameter',
                            'source' => 'ThingName'
                          }
                        ]
                      }
                    }
                  }
                },
                'resources' => {
                  'Thing' => {
                    'identifiers' => [{ 'name' => 'Name' }]
                  }
                }
              )

              expect(client).to receive(:make_thing).
                with(thing_name:'thing-name') do |params|
                  double('client-response',
                    context: double('request-context', params:params))
                end

              apply_definition

              svc = namespace::Resource.new
              thing = svc.create_thing(name:'thing-name')
              expect(thing.name).to eq('thing-name')
            end

            it 'can return an array of resources' do
              definition.update(
                'service' => {
                  'actions' => {
                    'CreateThings' => {
                      'request' => {
                        'operation' => 'MakeThings'
                      },
                      'resource' => {
                        'type' => 'Thing',
                        'identifiers' => [
                          {
                            # using JMESPath to extract thing names
                            'target' => 'Name',
                            'sourceType' => 'responsePath',
                            'source' => 'Things[].Name'
                          }
                        ]
                      }
                    }
                  }
                },
                'resources' => {
                  'Thing' => {
                    'identifiers' => [{ 'name' => 'Name' }]
                  }
                }
              )

              client_response = double('client-response', data: {
                'things' => [
                  { 'name' => 'thing1' },
                  { 'name' => 'thing2' },
                ]
              })
              expect(client).to receive(:make_things).
                and_return(client_response)

              apply_definition

              svc = namespace::Resource.new
              things = svc.create_things
              expect(things).to be_an(Batch)
              expect(things[0]).to be_kind_of(namespace::Thing)
              expect(things[1].client).to be(svc.client)
              expect(things.map(&:name)).to eq(['thing1', 'thing2'])
            end

            it 'can return hydrated resources' do
              definition.update(
                'service' => {
                  'actions' => {
                    'CreateThings' => {
                      'request' => {
                        'operation' => 'MakeThings'
                      },
                      'resource' => {
                        'type' => 'Thing',
                        'identifiers' => [
                          {
                            # using JMESPath to extract thing names
                            'target' => 'Name',
                            'sourceType' => 'responsePath',
                            'source' => 'Things[].Name'
                          }
                        ],
                      },
                      'path' => 'Things[]'
                    }
                  }
                },
                'resources' => {
                  'Thing' => {
                    'identifiers' => [{ 'name' => 'Name' }]
                  }
                }
              )

              client_response = double('client-response', data: {
                'things' => [
                  { 'name' => 'thing1', 'arn' => 'thing1-arn' },
                  { 'name' => 'thing2', 'arn' => 'thing2-arn' },
                ]
              })
              expect(client).to receive(:make_things).
                and_return(client_response)

              apply_definition

              svc = namespace::Resource.new
              things = svc.create_things
              expect(things.map(&:data)).to eq([
                { 'name' => 'thing1', 'arn' => 'thing1-arn' },
                { 'name' => 'thing2', 'arn' => 'thing2-arn' },
              ])
            end

          end

          describe 'has many associations' do

            let(:definition) {{
              'service' => {
                'hasMany' => {
                  'Things' => {
                    'request' => { 'operation' => 'ListThings' },
                    'resource' => {
                      'type' => 'Thing',
                      'identifiers' => [
                        {
                          'target' => 'Name',
                          'sourceType' => 'responsePath',
                          'source' => 'Things[].Name'
                        }
                      ],
                    },
                    'path' => 'Things[]'
                  }
                }
              },
              'resources' => {
                'Thing' => {
                  'identifiers' => [{ 'name' => 'Name' }]
                }
              }
            }}

            it 'returns an resource enumerator' do
              expect(client).to receive(:list_things).
                with(batch_size:2).
                and_return([
                  double('client-response-1', data: {
                    'things' => [
                      { 'name' => 'thing1', 'arn' => 'thing1-arn' },
                      { 'name' => 'thing2', 'arn' => 'thing2-arn' },
                    ]
                  }),
                  double('client-response-2', data: {
                    'things' => [
                      { 'name' => 'thing3', 'arn' => 'thing3-arn' },
                      { 'name' => 'thing4', 'arn' => 'thing4-arn' },
                    ]
                  }),
                ]
              )

              apply_definition

              svc = namespace::Resource.new
              things = svc.things(batch_size:2)
              expect(things).to be_an(Collection)
              expect(things.map(&:name)).to eq(%w(thing1 thing2 thing3 thing4))
            end

            it 'defines getter helpers for top-level resources' do
              apply_definition
              svc = namespace::Resource.new
              thing = svc.thing('thing-name')
              expect(thing).to be_kind_of(namespace::Thing)
              expect(thing.name).to eq('thing-name')
              expect(thing.client).to be(svc.client)
            end

          end

        end

        describe 'resources' do

          describe 'data attributes' do

            it 'defines a getter for each member of the resource shape' do
              definition['resources'] = {
                'Thing' => {
                  'identifiers' => [{ 'name' => 'Name' }],
                  'shape' => 'DataShape'
                }
              }
              shapes['StringShape'] = { 'type' => 'string' }
              shapes['DataShape'] = {
                'type' => 'structure',
                'members' => {
                  'Color' => { 'shape' => 'StringShape' },
                  'Size' => { 'shape' => 'StringShape' },
                }
              }
              apply_definition
              thing = namespace::Thing.new(name:'thing-name')
              expect(thing.class.data_attributes).to eq([:color, :size])
              expect(thing).to respond_to(:color)
              expect(thing).to respond_to(:size)
            end

            it 'does not redefine identifiers that have the same name' do
              definition['resources'] = {
                'Thing' => {
                  'identifiers' => [{ 'name' => 'Name' }],
                  'shape' => 'DataShape'
                }
              }
              shapes['StringShape'] = { 'type' => 'string' }
              shapes['DataShape'] = {
                'type' => 'structure',
                'members' => {
                  'Name' => { 'shape' => 'StringShape' },
                  'Color' => { 'shape' => 'StringShape' },
                  'Size' => { 'shape' => 'StringShape' },
                }
              }
              apply_definition
              thing = namespace::Thing.new(name:'thing-name')
              # notice that :name is not an attribute
              expect(thing.class.data_attributes).to eq([:color, :size])
              expect(thing.name).to eq('thing-name')
              expect(thing).to respond_to(:color)
              expect(thing).to respond_to(:size)
            end

            it 'raises an error if method already exists' do
              definition['resources'] = {
                'Thing' => {
                  'identifiers' => [{ 'name' => 'Name' }],
                  'actions' => {
                    'Load' => {
                      'request' => {
                        'operation' => 'MakeThings'
                      }
                    }
                  }
                }
              }
              msg = /unable to define method .*#load, method already exists/
              expect {
                apply_definition
              }.to raise_error(msg)
            end

          end

          describe '#load' do

            it 'raises a NotImplementedError when not specified' do
              definition['resources'] = {
                'Thing' => {
                  'identifiers' => [{ 'name' => 'Name' }]
                }
              }

              apply_definition

              allow(namespace::Thing).to receive(:name).and_return('Thing')

              expect {
                namespace::Thing.new(name:'thing-name').load
              }.to raise_error(NotImplementedError, '#load not defined for Thing')
            end

            it 'loads and caches resource data' do
              definition['resources'] = {
                'Thing' => {
                  'identifiers' => [{ 'name' => 'Name' }],
                  'shape' => 'DataShape',
                  'load' => {
                    'request' => {
                      'operation' => 'DescribeThing',
                      'params' => [
                        { 'target' => 'ThingName', 'sourceType' => 'identifier', 'source' => 'Name' }
                      ]
                    },
                    'path' => 'ThingData'
                  }
                }
              }
              shapes['StringShape'] = { 'type' => 'string' }
              shapes['DataShape'] = {
                'type' => 'structure',
                'members' => {
                  'Color' => { 'shape' => 'StringShape' },
                  'Size' => { 'shape' => 'StringShape' },
                }
              }

              apply_definition

              thing = namespace::Thing.new(name:'thing-name')

              resp1 = double('response', data: { 'thing_data' => {
                color: 'red',
                size: 'large',
              }})

              resp2 = double('response', data: { 'thing_data' => {
                color: 'blue',
                size: 'small',
              }})

              expect(thing.client).to receive(:describe_thing).
                with(thing_name:thing.name).
                and_return(resp1, resp2).
                twice

              expect(thing.data_loaded?).to be(false)
              expect(thing.load).to be(thing)
              expect(thing.data_loaded?).to be(true)
              expect(thing.color).to eq('red')
              expect(thing.size).to eq('large')
              expect(thing.reload).to be(thing)
              expect(thing.data_loaded?).to be(true)
              expect(thing.color).to eq('blue')
              expect(thing.size).to eq('small')
            end

          end

          describe 'actions' do

            it 'supports basic operations that return the client response' do
              definition['resources'] = {
                'Thing' => {
                  'identifiers' => [
                    { 'name' => 'Name' }
                  ],
                  'actions' => {
                    'Delete' => {
                      'request' => {
                        'operation' => 'DeleteThing',
                        'params' => [
                          { "target" => "ThingName", "sourceType" => "identifier", "source" => "Name" }
                        ]
                      }
                    }
                  }
                }
              }

              client_resp = double('client-response')
              expect(client).to receive(:delete_thing).
                with(thing_name: 'thing-name', foo:'bar').
                and_return(client_resp)

              apply_definition

              thing = namespace::Thing.new(name:'thing-name')
              resp = thing.delete(foo:'bar')
              expect(resp).to be(client_resp)
            end

            it 'supports operations that extract data' do
              definition['resources'] = {
                'Thing' => {
                  'identifiers' => [
                    { 'name' => 'Name' }
                  ],
                  'actions' => {
                    'Deactivate' => {
                      'request' => {
                        'operation' => 'DeactivateThing',
                        'params' => [
                          { "target" => "ThingName", "sourceType" => "identifier", "source" => "Name" }
                        ]
                      },
                      'path' => 'Thing.Status'
                    }
                  }
                }
              }

              data = { 'thing' => { 'status' => 'inactive' } }
              client_resp = double('client-response', data:data)
              expect(client).to receive(:deactivate_thing).
                and_return(client_resp)

              apply_definition

              thing = namespace::Thing.new(name:'thing-name')
              expect(thing.deactivate).to eq('inactive')
            end

            it 'supports operations that return singular resources' do
              definition['resources'] = {
                'Thing' => {
                  'identifiers' => [
                    { 'name' => 'Name' }
                  ],
                  'actions' => {
                    'Copy' => {
                      'request' => {
                        'operation' => 'CopyThing'
                      },
                      'resource' => {
                        'type' => 'Thing',
                        'identifiers' => [
                          {
                            'target' => 'Name',
                            'sourceType' => 'requestParameter',
                            'source' => 'ThingName'
                          }
                        ]
                      }
                    }
                  }
                }
              }

              expect(client).to receive(:copy_thing).
                with(thing_name:'new-thing-name') do |params|
                  double('client-response',
                    context: double('request-context', params:params))
                end

              apply_definition

              thing = namespace::Thing.new(name:'thing-name')
              new_thing = thing.copy(thing_name:'new-thing-name')
              expect(new_thing).to be_kind_of(namespace::Thing)
              expect(new_thing.client).to be(thing.client)
              expect(new_thing.name).to eq('new-thing-name')
            end

            it 'can return an array of resources' do
              definition['resources'] = {
                'Thing' => {
                  'identifiers' => [{ 'name' => 'Name' }],
                  'actions' => {
                    'CreateDooDad' => {
                      'request' => {
                        'operation' => 'CreateDooDad',
                        'params' => [
                          {
                            'target' => 'ThingName',
                            'sourceType' => 'identifier',
                            'source' => 'Name'
                          }
                        ]
                      },
                      'resource' => {
                        'type' => 'DooDad',
                        'identifiers' => [
                          {
                            'target' => 'ThingName',
                            'sourceType' => 'identifier',
                            'source' => 'Name'
                          },
                          {
                            'target' => 'Name',
                            'sourceType' => 'responsePath',
                            'source' => 'DooDad.DooDadName'
                          }
                        ]
                      }
                    }
                  }
                },
                'DooDad' => {
                  'identifiers' => [
                    { 'name' => 'ThingName' },
                    { 'name' => 'Name' }
                  ]
                }
              }

              client_response = double('client-response', data: {
                'doo_dad' => {
                  'doo_dad_name' => 'doo-dad-name'
                }
              })
              expect(client).to receive(:create_doo_dad).
                with(thing_name: 'thing-name').
                and_return(client_response)

              apply_definition

              thing = namespace::Thing.new(name:'thing-name')
              doo_dad = thing.create_doo_dad
              expect(doo_dad).to be_an(namespace::DooDad)
              expect(doo_dad.name).to eq('doo-dad-name')
              expect(doo_dad.client).to be(thing.client)
            end

            it 'can return hydrated resources' do
              definition['resources'] = {
                'Thing' => {
                  'identifiers' => [{ 'name' => 'Name' }],
                  'actions' => {
                    'CreateDooDad' => {
                      'request' => {
                        'operation' => 'CreateDooDad',
                        'params' => [
                          {
                            'target' => 'ThingName',
                            'sourceType' => 'identifier',
                            'source' => 'Name'
                          }
                        ]
                      },
                      'resource' => {
                        'type' => 'DooDad',
                        'identifiers' => [
                          {
                            'target' => 'ThingName',
                            'sourceType' => 'identifier',
                            'source' => 'Name'
                          },
                          {
                            'target' => 'Name',
                            'sourceType' => 'responsePath',
                            'source' => 'DooDad.DooDadName'
                          }
                        ]
                      },
                      'path' => 'DooDad'
                    }
                  }
                },
                'DooDad' => {
                  'identifiers' => [
                    { 'name' => 'ThingName' },
                    { 'name' => 'Name' }
                  ],
                  'shape' => 'DooDadShape'
                }
              }
              shapes['DooDadShape'] = { 'type' => 'structure' }

              data = {
                'doo_dad_name' => 'doo-dad-name',
                'description' => 'desc'
              }
              client_response = double('client-response', data: {
                'doo_dad' =>  data 
              })
              expect(client).to receive(:create_doo_dad).
                with(thing_name: 'thing-name').
                and_return(client_response)

              apply_definition

              thing = namespace::Thing.new(name:'thing-name')
              doo_dad = thing.create_doo_dad
              expect(doo_dad.data).to eq(data)
            end


          end

          describe 'has many associations' do

            it 'returns an Enumerator'

            it 'defines a getter for sub-resources'

            it 'does not define a getter for sibling resources'

          end

          describe 'has some associations' do

            it 'returns an array of resource objects'

          end

          describe 'has one associations' do

            it 'returns a single resource object'

          end

          describe 'waiters' do

            it 'uses the client waiter to poll for state change' do
              definition['resources'] = {
                'Thing' => {
                  'identifiers' => [{ 'name' => 'Name' }],
                  'shape' => 'ThingShape',
                  'waiters' => {
                    'Ready' => {
                      'waiterName' => 'ThingReady',
                      'params' => [
                        { 'target' => 'ThingName', 'sourceType' => 'identifier', 'source' => 'Name' }
                      ],
                      'path' => 'Thing'
                    }
                  }
                }
              }
              shapes['ThingShape'] = {
                'type' => 'structure',
                'members' => {
                  'Value' => { 'shape' => 'String' }
                }
              }
              shapes['String'] = { 'type' => 'string' }

              client_response = double('client-response', data: {
                'thing' =>  { value: 'abc' }
              })
              expect(client).to receive(:wait_until).
                with(:thing_ready, { thing_name: 'thing-name'}).
                and_return(client_response)

              apply_definition

              thing = namespace::Thing.new(name:'thing-name')
              thing2 = thing.wait_until_ready
              expect(thing2.identifiers).to eq(thing.identifiers)
              expect(thing2.client).to be(thing.client)
              expect(thing2.data_loaded?).to be(true)
              expect(thing2.value).to eq('abc')
            end

          end
        end
      end
    end
  end
end
