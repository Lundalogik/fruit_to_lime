require 'date'
module MoveToGo
    class OrganizationReference
        include SerializeHelper
        attr_accessor :id, :integration_id, :heading
        def serialize_variables
            [ :id, :integration_id, :heading ].map { |prop| {
                    :id => prop, :type => :string
                }
            }
        end

        def initialize(opt = nil)
            if opt != nil
                serialize_variables.each do |var|
                    value = opt[var[:id]]
                    instance_variable_set("@" + var[:id].to_s, value) if value != nil
                end
            end
        end

        def to_s
            return "(#{id}, #{integration_id}, #{heading})"
        end

        def empty?
            return !@integration_id && !@id && !@heading
        end

        def self.from_organization(organization)
            if organization.nil?
                return nil
            elsif organization.is_a?(Organization)
                return organization.to_reference
            elsif organization.is_a?(OrganizationReference)
                return organization
            end
        end
    end

    class Organization < CanBecomeImmutable
        include SerializeHelper, ModelHasCustomFields, ModelHasTags

        ##
        # :attr_accessor: id
        immutable_accessor :id
        ##
        # :attr_accessor: integration_id
        immutable_accessor :integration_id
        ##
        # :attr_accessor: name
        immutable_accessor :name
        ##
        # :attr_accessor: organization_number
        immutable_accessor :organization_number
        ##
        # :attr_accessor: email
        immutable_accessor :email
        ##
        # :attr_accessor: web_site
        immutable_accessor :web_site
        ##
        # :attr_accessor: postal_address
        immutable_accessor :postal_address
        ##
        # :attr_accessor: visit_address
        immutable_accessor :visit_address
        ##
        # :attr_accessor: central_phone_number
        immutable_accessor :central_phone_number
        ##
        # :attr_accessor: source
        immutable_accessor :source
        ##
        # :attr_accessor: source_data
        immutable_accessor :source_data
        attr_accessor :rootmodel

        # Sets/gets the date when this organization's relation was
        # changed. Default is Now.
        attr_reader :relation_last_modified

        attr_reader :employees, :responsible_coworker, :relation
        # you add custom values by using {#set_custom_value}
        attr_reader :custom_values

        # You can read linked objects
        attr_reader :deals, :histories, :documents

        def initialize(opt = nil)
            @employees = []
            if !opt.nil?
                serialize_variables.each do |myattr|
                    val = opt[myattr[:id]]
                    instance_variable_set("@" + myattr[:id].to_s, val) if val != nil
                end
            end

            @relation = Relation::NoRelation if @relation.nil?
            set_tag 'Import'
        end

        def to_reference()
            reference = OrganizationReference.new
            reference.id = @id
            reference.integration_id = @integration_id
            reference.heading = @name
            return reference
        end

        def ==(that)
            if that.nil?
                return false
            end

            if that.is_a? Organization
                return @integration_id == that.integration_id
            end

            return false
        end

        # @example Set city of postal address to 'Lund'
        #     o.with_postal_address do |addr|
        #         addr.city = "Lund"
        #     end
        # @see Address address
        def with_postal_address
            @postal_address = Address.new if @postal_address == nil
            yield @postal_address
        end

        # @example Set city of visit address to 'Lund'
        #     o.with_visit_address do |addr|
        #         addr.city = "Lund"
        #     end
        # @see Address address
        def with_visit_address
            @visit_address = Address.new if @visit_address == nil
            yield @visit_address
        end

        # @example Set the source to par id 4653
        #     o.with_source do |source|
        #          source.par_se('4653')
        #     end
        # @see ReferenceToSource source
        def with_source
            @source = ReferenceToSource.new if @source == nil
            yield @source
        end

        # @example Add an employee and then add additional info to that employee
        #    employee = o.add_employee({
        #        :integration_id => "79654",
        #        :first_name => "Peter",
        #        :last_name => "Wilhelmsson"
        #    })
        #    employee.direct_phone_number = '+234234234'
        #    employee.currently_employed = true
        # @see Person employee
        def add_employee(val)
            @employees = [] if @employees == nil
            person = if val.is_a? Person then val else Person.new(val) end
            person.set_organization_reference = self
            @employees.push(person)

            # *** TODO:
            #
            # The person should be immutable after it has been added
            # to the organization. However most sources (LIME Easy,
            # LIME Pro, Excel, SalesForce, etc) are updating the
            # person after is has been added to the organization. We
            # must update the sources before we can set the person
            # immutable here.

            #person.set_is_immutable

            return person
        end

        def responsible_coworker=(coworker)
            raise_if_immutable
            @responsible_coworker_reference = CoworkerReference.from_coworker(coworker)

            if coworker.is_a?(Coworker)
                @responsible_coworker = coworker
            end
        end

        def deals
            @rootmodel.find_deals_for_organization(self)
        end

        def histories
            @rootmodel.select_histories{|history| history.organization == self}
        end

        def documents(type)
            @rootmodel.select_documents(type){|doc| doc.organization == self}
        end

        # Sets the organization's relation to the specified value. The
        # relation must be a valid value from the Relation module
        # otherwise an InvalidRelationError error will be thrown.
        def relation=(relation)
            raise_if_immutable

            if relation == Relation::NoRelation || relation == Relation::WorkingOnIt ||
                    relation == Relation::IsACustomer || relation == Relation::WasACustomer || relation == Relation::BeenInTouch
                @relation = relation
                @relation_last_modified = Time.now.strftime("%Y-%m-%d") if @relation_last_modified.nil? &&
                    @relation != Relation::NoRelation
            else
                raise InvalidRelationError
            end
        end

        def relation_last_modified=(date)
            raise_if_immutable

            begin
                @relation_last_modified = @relation != Relation::NoRelation ? Date.parse(date).strftime("%Y-%m-%d") : nil
            rescue
                raise InvalidValueError, date
            end
        end

        def find_employee_by_integration_id(integration_id)
            return nil if @employees.nil?
            return @employees.find do |e|
                e.integration_id == integration_id
            end
        end

        def serialize_variables
            [
             { :id => :id, :type => :string },
             { :id => :integration_id, :type => :string },
             { :id => :source, :type => :source_ref },
             { :id => :name, :type => :string },
             { :id => :organization_number, :type => :string },
             { :id => :postal_address, :type => :address },
             { :id => :visit_address, :type => :address },
             { :id => :central_phone_number, :type => :string },
             { :id => :email, :type => :string },
             { :id => :web_site, :type => :string },
             { :id => :employees, :type => :persons },
             { :id => :custom_values, :type => :custom_values },
             { :id => :tags, :type => :tags },
             { :id => :responsible_coworker_reference, :type => :coworker_reference, :element_name => :responsible_coworker},
             { :id => :relation, :type => :string },
             { :id => :relation_last_modified, :type => :string }
            ]
        end

        def serialize_name
            "Organization"
        end

        def to_s
            return "#{name}"
        end

        def validate
            error = String.new

            if @name.nil? || @name.empty?
                error = "A name is required for organization.\n#{serialize()}"
            end

            if !@source.nil?
                if @source.id.nil? || @source.id == ""
                    error = "#{error}\nReference to source must have an id"
                elsif @source.id !~ /^\d{1}\d*:{1}\d{1}\d*$/
                    error = "#{error}\nInvalid source id '#{@source.id}', must have one ':' and only digits allowed, example '1:200010'"
                end
            end

            if @employees != nil
                @employees.each do |person|
                    validation_message = person.validate()
                    if !validation_message.empty?
                        error = "#{error}\n#{validation_message}"
                    end
                end
            end

            return error
        end

        # Moves all data from an organization to this organization. The pillaged
        # org is still kept as a empty shell of itself in the rootmodel 
        def move_data_from(org)
            flat_instance_variables_to_copy = [:@name, :@organization_number, :@email, :@web_site, :@central_phone_number]
            class_instance_variables_to_copy = [:@visiting_address, :@postal_address, :@source_data]
            org.instance_variables.each{ |variable|
                
                # Only change the value if it is empty
                if flat_instance_variables_to_copy.include? variable
                    if !self.instance_variable_get(variable)
                        self.instance_variable_set(variable, org.instance_variable_get(variable))
                    end

                # Some of the instances variabels are classes
                
                elsif class_instance_variables_to_copy.include? variable
                  
                    class_instance = org.instance_variable_get(variable)
                    class_instance.instance_variables.each { |sub_variable|
                       
                        #If there is no class, create one 
                        if !self.instance_variable_get(variable)
                            case variable
                            when :@visit_address, :@postal_address
                                klass = MoveToGo::Address.new
                            when :@source_data
                                klass = MoveToGo::SourceData.new
                            end
                            self.instance_variable_set(variable, klass)
                        end
                        if !self.instance_variable_get(variable).instance_variable_get(sub_variable)
                            self.instance_variable_get(variable).instance_variable_set(
                                sub_variable, class_instance.instance_variable_get(sub_variable)
                            )
                        end
                    }
                elsif variable == :@custom_values
                    org.custom_values.each{ |custom_value|
                        self.set_custom_value(custom_value.field, custom_value.value)
                    }
                end
            }

            self.with_postal_address do

            end
            
            org.employees.each{ |person| self.add_employee(person)}
    
            org.deals.each{ |deal| deal.instance_variable_set("@customer", self)} # Object is "immutable" if using "="

            org.histories.each{|history| history.instance_variable_set("@organization", self)}

            org.documents(:file).each{|file| file.instance_variable_set("@organization", self)}

            org.documents(:link).each{|history| history.instance_variable_set("@organization", self)}

        end
    end
end
