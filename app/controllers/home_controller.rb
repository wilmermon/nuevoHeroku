class HomeController < ApplicationController
   before_action :set_concurso

   def index
		
   end
	
   def find
     #@vocess_locutor = VocessLocutor.new
     #@concursos = Concurso.new
   end
	
   private
   def set_concurso
    	if administrator_signed_in?
#         @concursos = Concurso.where administrator_id: current_administrator.id
 	  Aws.config.update({ region: "us-east-2" })
          credentials = Aws::SharedCredentials.new(profile_name: 'default')
          dynamodb = Aws::DynamoDB::Client.new(credentials: credentials)
          table_name = 'concursos'

          parameter = {
            table_name: table_name,
            key_condition_expression: "#admin = :administrator",
            expression_attribute_names: {
              "#admin" => "administrator_id"
            },
            expression_attribute_values: {
               ":administrator" => current_administrator.id
            }
          }

          begin
                @concursos = dynamodb.query(parameter)
                puts "Query succeeded."
          rescue  Aws::DynamoDB::Errors::ServiceError => error
                puts "Unable to query table:"
                flash[:danger] = "#{error.message}"
          end

	end
   end
end
