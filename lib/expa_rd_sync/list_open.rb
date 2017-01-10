module ExpaRdSync
  class ListOpen
    def self.call
      new.call
    end

    attr_accessor :rd_identifiers, :rd_tags

    attr_reader :status

    def initialize
      self.rd_identifiers = {
        :test => 'test', #This is the identifier that should always be used during test phase
        :form_podio_offline => 'form-podio-offline',
        :expa => 'expa',
        :open => 'open',
        :landing_0 => 'completou-cadastro',
        :landing_1 => 'form-video-suporte-aiesec',
        :landing_2 => '15-dicas-para-planejar-sua-viagem-sem-imprevistos',
        :in_progress => 'in_progress',
        :rejected => 'rejected',
        :accepted => 'accepted',
        :approved => 'approved'
      }

      self.rd_tags = {
          :gip => 'GIP',
          :gcdp => 'GCDP'
      }

      @status = true
    end

    def call
      setup_expa_api

      time = ExpaPerson.get_last_xp_created_at - 60 || Time.now - 10*60

      people = EXPA::People.list_everyone_created_after(time)

      @status = false unless act_on_people(people)

      puts "Listed #{people.length} people finishing #{Time.now}"

      @status
    end

    private

    def setup_expa_api
      if EXPA.client.nil?
        xp = EXPA.setup
        xp.auth(ENV['ROBOZINHO_EMAIL'],ENV['ROBOZINHO_PASSWORD'])
      end
    end

    def act_on_people(people)
      people.each do |xp_person|
        if ExpaPerson.find_by(xp_id: xp_person.id) || ExpaPerson.find_by(xp_email: xp_person.email.downcase)
          update_db_peoples(xp_person)
        else
          person = ExpaPerson.new
          person.update_from_expa(xp_person)
          person.save
          send_to_rd(person, nil, self.rd_identifiers[:open], nil)
        end
      end
    end

    def update_db_peoples(xp_person)
      person = ExpaPerson.find_by(xp_id: xp_person.id) || ExpaPerson.find_by(xp_email: xp_person.email)

      if person.nil?
        person = ExpaPerson.new
        person.update_from_expa(xp_person)
        person.save
      else
        if person.xp_status != xp_person.status.to_s.downcase.gsub(' ','_')
          person.update_from_expa(xp_person)
          person.save
          case person.xp_status
            when 'in_progress'then send_to_rd(person, nil, self.rd_identifiers[:in_progress], nil) #TODO mandar se é GCDP ou GIP
            when 'accepted' then send_to_rd(person, nil, self.rd_identifiers[:accepted], nil)
            when 'approved' then send_to_rd(person, nil, self.rd_identifiers[:approved], nil)
            else nil
          end
        end
      end

      setup_expa_api
      applications = EXPA::People.get_applications(person.xp_id) # unless xp_person.xp_home_mc_id == 1606
      if applications.any?
        applications.each do |xp_application|
          update_db_applications(xp_application)
        end
      end
      send_to_rd(person, nil, self.rd_identifiers[:expa], nil) #TODO enviar tambem applications (somente quanto ta accepted, match, relized, complted)

      person
    end

    def update_db_applications(xp_application)
      application = ExpaApplication.find_by_xp_id(xp_application.id)

      if application.nil?
        application = ExpaApplication.new
      end

      application.update_from_expa(EXPA::Applications.get_attributes(xp_application.id))
      application.save
    end

    def send_to_rd(person, application, identifier, tag)
      #TODO: colocar todos os campos do peoples e applications aqui no RD
      #TODO: colocar breaks conferindo todos os campos
      json_to_rd = {}
      json_to_rd['token_rdstation'] = ENV['RD_STATION_TOKEN']
      json_to_rd['identificador'] = identifier
      json_to_rd['email'] = person.xp_email unless person.xp_email.nil?
      json_to_rd['nome'] = person.xp_full_name unless person.xp_full_name.nil?
      json_to_rd['expa_id'] = person.xp_id unless person.xp_id.nil?
      json_to_rd['data_de_nascimento'] = person.xp_birthday_date unless person.xp_birthday_date.nil?
      json_to_rd['entidade'] = person.xp_home_lc.xp_name unless person.xp_home_lc.nil?
      json_to_rd['pais'] = person.xp_home_mc.xp_name unless person.xp_home_mc.nil?
      json_to_rd['status'] = person.xp_status unless person.xp_status.nil?
      json_to_rd['entrevistado'] = person.xp_interviewed  unless person.xp_interviewed.nil?
      json_to_rd['telefone'] = person.xp_phone unless person.xp_phone.nil?
      json_to_rd['pagamento'] = person.xp_payment unless person.xp_payment.nil?
      json_to_rd['nps'] = person.xp_nps_score unless person.xp_nps_score.nil?
      json_to_rd['entidade_OGX'] = person.entity_exchange_lc.xp_name unless person.entity_exchange_lc.nil?
      json_to_rd['como_conheceu_AIESEC'] = person.how_got_to_know_aiesec unless person.how_got_to_know_aiesec.nil?
      json_to_rd['programa_interesse'] = person.interested_program unless person.interested_program.nil?
      json_to_rd['sub_produto_interesse'] = person.interested_sub_product unless person.interested_sub_product.nil?
      json_to_rd['tag'] = tag unless tag.nil?
      unless application.nil?
        json_to_rd.merge!{
        }
      end
      uri = URI(ENV['RD_STATION_URL'])
      https = Net::HTTP.new(uri.host,uri.port)
      https.use_ssl = true
      req = Net::HTTP::Post.new(uri.path, initheader = {'Content-Type' =>'application/json'})
      req.body = json_to_rd.to_json
      begin
        puts https.request(req)
      rescue => exception
        puts exception.to_s
      end
    end
  end
end
