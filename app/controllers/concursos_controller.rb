class ConcursosController < ApplicationController
    #before_action :set_concurso, only: [:show, :edit, :update, :destroy]
    require "aws-sdk"
    require 'securerandom'

    def index
        if administrator_signed_in?
          #@concursos = Concurso.where administrator_id: current_administrator.id
          Aws.config.update({ region: "us-east-2" })
          dynamodb = Aws::DynamoDB::Client.new( access_key_id: ENV['Dynamo_KEY'],
                                                secret_access_key: ENV['Dynamo_SECRET'])
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
	
  def homeConcursos
        session[:concursoURL] = params[:concursoURL]
        Aws.config.update({ region: "us-east-2" })
        dynamodb = Aws::DynamoDB::Client.new( access_key_id: ENV['Dynamo_KEY'],
                                                secret_access_key: ENV['Dynamo_SECRET'])
        table_name = 'concursos'
#	@concursos = Concurso.find_by concursoURL: params[:concursoURL]
#	@concursos = Concurso.find_by concursoURL: params[:concursoURL)
#	@vocess_locutors = @concursos.vocess_locutors.where(:estado => 'Convertida').paginate(:page => params[:page], per_page: 30).order(created_at: :desc)
        parameter = {
           table_name: table_name,
           index_name: 'concursoURL-index',
           select: 'ALL_PROJECTED_ATTRIBUTES',
           key_condition_expression: "concursoURL = :concursoURL",
           expression_attribute_values: {
                ":concursoURL" => params[:concursoURL]
           }
        }
        begin
            @concursos =  dynamodb.query(parameter)
            @concursos.items.each{|concurso|
                session[:concurso_id] = concurso["id"]
            }

            table_name = 'vocess_locutors'
            parameter = {
                table_name: table_name,
                index_name: 'estado-concurso_id-index',
                select: 'ALL_PROJECTED_ATTRIBUTES',
                key_condition_expression: "concurso_id = :concurso and estado = :est",
                expression_attribute_values: {
                    ":concurso" => session[:concurso_id],
                    ":est" => 'En proceso'
                }
            }
            @vocess_locutors = dynamodb.query(parameter)
            puts "Query succeeded."
            @vocess_locutor_new = VocessLocutor.new
            @concurso_voz_new = Concurso.new
        rescue  Aws::DynamoDB::Errors::ServiceError => error
            puts "Unable to query table:"
            flash[:danger] = "#{error.message}"
        end
    end

    def find
        @vocess_locutor = VocessLocutor.new
        @concursos = Concurso.new
    end

    def new
	@concursos = Concurso.new
	session[:concurso_id] = nil
    end
    
    def create
        Aws.config.update({ region: "us-east-2" })
        dynamodb = Aws::DynamoDB::Client.new( access_key_id: ENV['Dynamo_KEY'],
                                              secret_access_key: ENV['Dynamo_SECRET'])
        #render plain: params[:concurso].inspect
        @concursos = current_administrator.concursos.new concurso_params
        begin
          table_name = 'concursos'
          if session[:concurso_id].nil?
             concurso_id = SecureRandom.hex
             url_imagen = @concursos.image_url
             cache_imagen = @concursos.cached_image_data
             created = Time.now.to_s
          else
             parameter = {
                table_name: table_name,
                    key: {
                        administrator_id: current_administrator.id,
                        id: session[:concurso_id]
                   }
             }
             result = dynamodb.get_item(parameter)
             concurso_id = session[:concurso_id]
             created = result.item["created_at"]

             if @concursos.image_url.nil?
                url_imagen = result.item["imageBanner"]
                cache_imagen = result.item["image_data"]
             else
                url_imagen = @concursos.image_url
                cache_imagen = @concursos.cached_image_data
             end
           end
           item = {
                administrator_id: @concursos.administrator_id,
                id: concurso_id,
                nombreConcurso: @concursos.nombreConcurso,
                fechaInicio: @concursos.fechaInicio.to_s,
                fechaFin: @concursos.fechaFin.to_s,
                valorPagar: @concursos.valorPagar,
                recomendaciones: @concursos.recomendaciones,
                guionConcurso: @concursos.guionConcurso,
                imageBanner: url_imagen,
                image_data: cache_imagen,
                concursoURL: @concursos.concursoURL,
                created_at: created,
                updated_at: Time.now.to_s
           }
           params = {
                table_name: table_name,
                item: item
           }
           result = dynamodb.put_item(params)
           redirect_to @concursos
        rescue  Aws::DynamoDB::Errors::ServiceError => error
           puts "No se puede crear el concurso:"
           flash[:danger] = "#{error.message}"
#	   flash[:danger] = 'Ha ocurrido un error y no se creó el concurso. Revise la información y el formato del archivo guardado e inténtelo de nuevo.'
        end
    end

    def show
        Aws.config.update({ region: "us-east-2" })
        dynamodb = Aws::DynamoDB::Client.new( access_key_id: ENV['Dynamo_KEY'],
                                              secret_access_key: ENV['Dynamo_SECRET'])
        #render plain: params[:concurso].inspect
        session[:concurso_id] = params[:id]
        table_name = 'concursos'
        parameter = {
            table_name: table_name,
                key: {
                   administrator_id: current_administrator.id,
                   id: session[:concurso_id]
                }
        }
        begin
            @concurso = dynamodb.get_item(parameter)

            table_name = 'vocess_locutors'
            parameter = {
                table_name: table_name,
                key_condition_expression: "concurso_id = :concurso",
                expression_attribute_values: {
                        ":concurso" => session[:concurso_id],
                }
            }
            @vocess_locutors = dynamodb.query(parameter)
            puts "Query succeeded."

        rescue  Aws::DynamoDB::Errors::ServiceError => error
                flash[:danger] = "#{error.message}"
        end
    end

   def edit
        @concursos = Concurso.new
        Aws.config.update({ region: "us-east-2" })
        dynamodb = Aws::DynamoDB::Client.new( access_key_id: ENV['Dynamo_KEY'],
                                              secret_access_key: ENV['Dynamo_SECRET'])
        table_name = 'concursos'
        session[:concurso_id] = params[:id]
        parameter = {
            table_name: table_name,
                key: {
                   administrator_id: current_administrator.id,
                   id: session[:concurso_id]
                }
        }
        begin
            result = dynamodb.get_item(parameter)
            @concursos.administrator_id = result.item["administrator_id"]
            @concursos.id = result.item["id"]
            @concursos.nombreConcurso = result.item["nombreConcurso"]
            @concursos.fechaInicio = result.item["fechaInicio"]
            @concursos.fechaFin = result.item["fechaFin"]
            @concursos.valorPagar = result.item["valorPagar"]
            @concursos.recomendaciones = result.item["recomendaciones"]
            @concursos.guionConcurso = result.item["guionConcurso"]
            @concursos.imageBanner = result.item["imageBanner"]
            @concursos.concursoURL = result.item["concursoURL"]
            @concursos.created_at = result.item["created_at"]
            @concursos.updated_at = result.item["updated_at"]
            @concursos.image_data = result.item["image_data"]
        rescue  Aws::DynamoDB::Errors::ServiceError => error
           flash[:danger] = "#{error.message}"
        end
    end

    def update
#       @concursos = Concurso.find params[:id]
#       @concursos.imageBanner = @concursos.image_url
#       @concursos.update concurso_params
#       redirect_to @concursos
    end


    def update
#	@concursos = Concurso.find params[:id]
#	@concursos.imageBanner = @concursos.image_url
#	@concursos.update concurso_params
#	redirect_to @concursos
    end

    def destroy
#       @concursos = Concurso.find params[:id]
        Aws.config.update({ region: "us-east-2" })
        dynamodb = Aws::DynamoDB::Client.new( access_key_id: ENV['Dynamo_KEY'],
                                              secret_access_key: ENV['Dynamo_SECRET'])
        table_name = 'concursos'
        parameter = {
            table_name: table_name,
            key: {
                administrator_id: current_administrator.id,
                id: params[:id]
            }
        }
        begin
            result = dynamodb.delete_item(parameter)
            puts "Deleted item."
        rescue  Aws::DynamoDB::Errors::ServiceError => error
            puts "Unable to update item:"
            flash[:danger] = "#{error.message}"
        end
        redirect_to concursos_path
    end

    private
    def concurso_params
        params.require(:concurso).permit(:nombreConcurso, :fechaInicio, :fechaFin, :valorPagar, :recomendaciones, :guionConcurso, :image, :concursoURL)
    end
end

