##
# Control everything about Session: Login, Logout etc. It also control the initial page
class SessionsController < ApplicationController
  # GET /
  def index
    if session[:expa_id]
      if EXPA.client.nil?
        expa = EXPA.setup()
      else
        expa = nil
        EXPA.client = nil
        expa = EXPA.setup()
      end

      expa.auth(session[:mail],session[:pass])
      return redirect_to main_path
    end
    render layout: "empty"
  end

  # POST /
  def login
    mail = params[:email]
    pass = params[:password]

    if EXPA.client.nil?
      expa = EXPA.setup()
    else
      expa = nil
      EXPA.client = nil
      expa = EXPA.setup()
    end

    expa.auth(mail,pass)

    if expa.get_token.nil?
      flash[:warning] = "E-mail ou senha inválida"
      redirect_to(:action => "error")
    else
      user = ExpaPerson.find_by_xp_email(mail)
      if user.nil?
        user = ExpaPerson.new
        user.update_from_expa(EXPA::CurrentPerson.get_current_person)
      end
      user.update_from_expa(EXPA::People.find_by_id(user.xp_id))
      user.save
      reset_session
      session[:expa_id] = user.xp_id
      session[:mail] = mail
      session[:password] = pass
      redirect_to main_path
    end
  end

  # GET /
  def logout
    reset_session
    redirect_to root_path
  end
end