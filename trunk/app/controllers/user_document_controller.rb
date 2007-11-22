require RAILS_ROOT + '/lib/salva'
require RAILS_ROOT + '/lib/finder'
class UserDocumentController < ApplicationController
  include Salva
  layout 'user_document_handling'
  before_filter :document_requirements

  def initialize
    @documenttype = Documenttype.find(:first, :conditions => ["name = ?", @document_name])
    @document = Document.find(:first, :conditions => "documents.documenttype_id = #{@documenttype.id}", :order => 'documents.startdate DESC') if !@documenttype.nil?
  end

  def index
     list
  end

  def list
    unless @documenttype.nil?
      @collection = UserDocument.paginate :page => 1, :per_page => 10, :include => [:document], :order => 'documents.startdate DESC',
      :conditions => "user_id = #{@user.id} AND user_documents.document_id = documents.id AND documents.documenttype_id = #{@documenttype.id}"
    else
      @collection = []
      flash[:notice] = "Debe activar el #{@document_name}"
    end
    render :action => 'list'
  end

  def send_document
    record = UserDocument.new
    record.ip_address = request.remote_ip
    record.document_id = @document.id
    record.file = StringIO.new(@file).read
    record.filename  = @filename
    record.content_type = 'application/pdf'
    record.moduser_id = @user.id
    record.user_id = @user.id
    record.status = true
    record.user_incharge_id = @user.user_incharge_id and record.status = false if @user.has_user_incharge?
    if record.save
      if @user.has_user_incharge?
        send_email(@user.email, "Solicitud de aprobación (#{@document_title})", :deliver_request_for_approval, { :file => record.file,  :content_type => record.content_type, :filename => @filename })
        send_email(@user.user_incharge.email, "Solicitud de aprobación del #{@document_title}", :deliver_request_for_approval_notification)
      else
        send_email(@user.email, "#{@document_title}", :deliver_notification_of_delivery, { :file => record.file,  :content_type => record.content_type, :filename => @filename })
      end
      flash[:notice] = "Su #{@document_title} ha sido enviado!"
    else
      flash[:notice] = "Su #{@document_title} NO ha sido enviado!" + record.errors.full_messages.join(', ')
    end
    redirect_to :action => 'list'
  end

  def show
    @record = UserDocument.find(:first, :conditions => ['user_id = ? AND id = ?', @user.id,  params[:id]])
    if !@record.nil?
      response.headers['Pragma'] = 'no-cache'
      response.headers['Cache-Control'] = 'no-cache, must-revalidate'
      send_data(@record.file, :filename => @record.filename, :type => @record.content_type, :disposition => "inline")
    else
      flash[:notice] = 'Documento no encontrado'
      redirect_to :action => 'list'
    end
  end

  def purge
    @record = UserDocument.find(:first, :conditions => ['user_id = ? AND id = ?', @user.id,  params[:id]])
    if !@record.nil?
        @record.destroy
    else
        flash[:notice] = 'Documento no encontrado'
        redirect_to :action => 'list'
    end
  end
  
  private
  def document_requirements
    if !@documenttype.nil? and !@document.nil?
      @user = User.find(session[:user])
      if UserDocument.find(:first, :conditions => ['document_id = ? AND user_id  = ?', @document.id, @user.id]).nil? and @document.enddate <= Date.today
        @document_title, @document_id = Finder.new(Document, :first, :attributes => [['documenttype', 'name'], 'title'],
                                                   :conditions => "documents.documenttype_id = #{@documenttype.id}",
                                                   :order => 'documents.startdate DESC').as_pair.first
        @document_title.gsub!(/,/,'')                               
      end
    end
  end

  def send_email(recipients, subject, method, attachment=nil)
    options =  { :recipients => recipients, :subject => subject, :body => { :institution => get_myinstitution.name } }
    options[:attachment] = attachment unless attachment.nil?
    UserDocumentNotifier.send(method, options)
  end

  def filename(ext='pdf')
      @document_title.downcase.gsub(/,+/,'').gsub(/\s+/,'_') + '.' + ext
  end

  def report_code
    'SALVA - Plat. Inf. Curric. ' + request.remote_ip + ' ' + Time.now.ctime
  end
end
