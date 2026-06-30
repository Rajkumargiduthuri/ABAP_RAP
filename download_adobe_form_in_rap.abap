"D𝗼𝘄𝗻𝗹𝗼𝗮𝗱𝗶𝗻𝗴 𝗔𝗱𝗼𝗯𝗲 𝗳𝗼𝗿𝗺𝘀 𝗼𝗿 𝗮𝗻𝘆 𝗳𝗶𝗹𝗲𝘀 𝗶𝗻 𝗥𝗔𝗣.  
"if you’ve tried this before, you might have noticed that methods like 𝗚𝗨𝗜_𝗗𝗢𝗪𝗡𝗟𝗢𝗔𝗗 or 𝗰𝗹_𝗴𝘂𝗶_𝗳𝗿𝗼𝗻𝘁𝗲𝗻𝗱_𝘀𝗲𝗿𝘃𝗶𝗰𝗲𝘀=>𝗴𝘂𝗶_𝗱𝗼𝘄𝗻𝗹𝗼𝗮𝗱 don’t work in RAP. 
"So, what’s the alternative? This can be achieved using streams (file upload) in RAP, combined with some additional logic. 
"Here are the two approaches I followed in my example: 

"1. 𝗖𝗿𝗲𝗮𝘁𝗲 𝗮𝗻 𝗮𝗰𝘁𝗶𝗼𝗻 to populate your stream fields with form data. 
"2. Use a 𝘃𝗶𝗿𝘁𝘂𝗮𝗹 𝗲𝗹𝗲𝗺𝗲𝗻𝘁 to fill your stream fields (not recommended, as it may trigger your Adobe form method multiple times). 
"Note: Ensure that your stream fields (attachment fields) are set to read-only,since it's getting filled through our logic. For the below Example I’ve created on OdataV4 – UI

"1.	Create a Table
@EndUserText.label : 'Employee DATA'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zsb_emp_file_det {

  key client            : abap.clnt not null;
  key employeeid        : pernr_d not null;
  employeename          : text100;
  attachment            : /dmo/attachment;
  mimetype              : /dmo/mime_type;
  filename              : /dmo/filename;
  local_created_by      : abp_creation_user;
  local_created_at      : abp_creation_tstmpl;
  local_last_changed_by : abp_locinst_lastchange_user;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
  last_changed_at       : abp_lastchange_tstmpl;
}


"2.	Create a Root Entity
@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: '###GENERATED Core Data Service Entity'
@ObjectModel.sapObjectNodeType.name: 'Zsb_Emp_File_DET'
define root view entity ZR_SB_EMP_FILE_DET
  as select from zsb_emp_file_det
{
  key employeeid as Employeeid,
  employeename as Employeename,
  @Semantics.largeObject:{ fileName: 'Filename',mimeType: 'Mimetype',contentDispositionPreference: #ATTACHMENT }
  attachment as Attachment,
  @Semantics.mimeType: true
  mimetype as Mimetype,
  filename as Filename,
  @Semantics.user.createdBy: true
  local_created_by as LocalCreatedBy,
  @Semantics.systemDateTime.createdAt: true
  local_created_at as LocalCreatedAt,
  @Semantics.user.localInstanceLastChangedBy: true
  local_last_changed_by as LocalLastChangedBy,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  local_last_changed_at as LocalLastChangedAt,
  @Semantics.systemDateTime.lastChangedAt: true
  last_changed_at as LastChangedAt
  
}

"3.	Create a Projection View
@ObjectModel.sapObjectNodeType.name: 'Zsb_Emp_File_DET'
define root view entity ZC_SB_EMP_FILE_DET
  provider contract transactional_query
  as projection on ZR_SB_EMP_FILE_DET
{
  key Employeeid,
  Employeename,
  LocalCreatedBy,
  LocalCreatedAt,
  LocalLastChangedBy,
  LocalLastChangedAt,
  LastChangedAt,
  
  Attachment,
  Mimetype,
  Filename,
  
  @Semantics.largeObject:{ fileName: 'vfilename', mimeType: 'vmimetype', contentDispositionPreference: #ATTACHMENT }
  @ObjectModel.virtualElement: true
  @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_FILE_VIRTUAL'
  virtual vattachment            : /dmo/attachment,
  
  @ObjectModel.virtualElement: true
  @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_FILE_VIRTUAL'
  @Semantics.mimeType: true
  virtual vmimetype              : /dmo/mime_type,
  
  @ObjectModel.virtualElement: true
  @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_FILE_VIRTUAL'
  virtual vfilename              : /dmo/filename
  
}

"4.	Metadata Extensions
@Metadata.layer: #CORE
@UI.headerInfo.title.type: #STANDARD
@UI.headerInfo.title.value: 'Employeeid'
@UI.headerInfo.description.type: #STANDARD
@UI.headerInfo.description.value: 'Employeeid'
annotate view ZC_SB_EMP_FILE_DET with
{
  @UI.facet: [ {
    label: 'General Information', 
    id: 'GeneralInfo', 
    purpose: #STANDARD, 
    position: 10 , 
    type: #IDENTIFICATION_REFERENCE
  } ]
  @UI.identification: [ {  position: 10,label: 'Employee Id' },
                        { type: #FOR_ACTION, dataAction: 'downloadForm', label: 'Download Adobe Form' } ]
  @UI.lineItem: [ { position: 10,label: 'Employee Id' } ]
  @UI.selectionField: [ { position: 10 } ]
  Employeeid;
  
  @UI.identification: [ {  position: 20, label :'Employee Name' } ]
  @UI.lineItem: [ { position: 20, label: 'Employee Name' } ]
  Employeename;
  
  @UI.identification: [ { position: 30, label: 'Attachment(Based on Action)' } ]
  Attachment;
  
  @UI.identification: [ { position: 30, label: 'Attachment(Based on Virtual Element)' } ]
  vattachment;
  
  @UI.hidden: true
  Mimetype;
  @UI.hidden: true
  Filename;
}


"5.	Behaviour Defination
managed implementation in class ZBP_R_SB_EMP_FILE_DET unique;
strict ( 2 );
with draft;
define behavior for ZR_SB_EMP_FILE_DET alias ZrSbEmpFileDet
persistent table ZSB_EMP_FILE_DET
draft table ZSB_EMP_FLE_DT_D
etag master LocalLastChangedAt
lock master total etag LastChangedAt
authorization master( global )

{

  field( mandatory : create, readonly : update  ) Employeeid;
  field ( readonly )
   LocalCreatedBy,
   LocalCreatedAt,
   LocalLastChangedBy,
   LocalLastChangedAt,
   LastChangedAt;

  field ( readonly ) Attachment;
  action downloadForm result [0..1] $self;

  create;
  update;
  delete;

  draft action Activate optimized;
  draft action Discard;
  draft action Edit;
  draft action Resume;
  draft determine action Prepare;

  mapping for ZSB_EMP_FILE_DET
  {
    Employeeid = employeeid;
    Employeename = employeename;
    Attachment = attachment;
    Mimetype = mimetype;
    Filename = filename;
    LocalCreatedBy = local_created_by;
    LocalCreatedAt = local_created_at;
    LocalLastChangedBy = local_last_changed_by;
    LocalLastChangedAt = local_last_changed_at;
    LastChangedAt = last_changed_at;
  }
}

"6.	Behaviour Implementation - Action code
METHOD downloadForm.

    DATA: lt_update TYPE TABLE FOR UPDATE zr_sb_emp_file_det.

    lt_update = VALUE #( for key in keys (
                          %tky = key-%tky
                          Attachment = NEW ZCL_SB_FORM( )->get_form( key-Employeeid ) "This logic added in the below
                          Filename = |Adobe_Form.pdf|
                          Mimetype = 'APPLICATION/PDF'
                          %control = VALUE #( Attachment = if_abap_behv=>mk-on
                                              Filename   = if_abap_behv=>mk-on
                                              Mimetype   = if_abap_behv=>mk-on )
                        ) ).

    MODIFY ENTITIES OF zr_sb_emp_file_det IN LOCAL MODE
      ENTITY ZrSbEmpFileDet
      UPDATE FROM lt_update
      REPORTED DATA(lt_update_reported)
    FAILED DATA(lt_update_failed).

    READ ENTITIES OF zr_sb_emp_file_det IN LOCAL MODE
      ENTITY ZrSbEmpFileDet
      ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_result).

    result = VALUE #( for ls_result in lt_result (
                      %tky = ls_result-%tky
                      %param = CORRESPONDING #( ls_result ) ) ).

  ENDMETHOD.

"7.	Behaviour Projection
projection;
strict ( 2 );
use draft;
define behavior for ZC_SB_EMP_FILE_DET alias ZcSbEmpFileDet
use etag

{
  use create;
  use update;
  use delete;

  use action downloadForm;

  use action Edit;
  use action Activate;
  use action Discard;
  use action Resume;
  use action Prepare;
}

"8.	Service Definition and Service Binding
@EndUserText: {
  label: 'Service Definition for ZC_SB_EMP_FILE_DET'
}
@ObjectModel: {
  leadingEntity: {
    name: 'ZC_SB_EMP_FILE_DET'
  }
}
define service ZUI_SB_EMP_FILE_DET_O4 {
  expose ZC_SB_EMP_FILE_DET;
}
* Create a service binding with OData V4 - UI

"9.	Vitrual Element calculation Class -
CLASS zcl_file_virtual DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_sadl_exit .
    INTERFACES if_sadl_exit_calc_element_read .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_file_virtual IMPLEMENTATION.
  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA : lt_emp_data TYPE TABLE OF zc_sb_emp_file_det.
    lt_emp_data =  CORRESPONDING #( it_original_data ).

    LOOP AT lt_emp_data ASSIGNING FIELD-SYMBOL(<fs_emp>).
      <fs_emp>-vattachment = NEW ZCL_SB_FORM( )->get_form( <fs_emp>-Employeeid ). "This logic added in the below
      <fs_emp>-vfilename = |Adobe_Form.pdf|.
      <fs_emp>-vmimetype = 'APPLICATION/PDF' .
    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( lt_emp_data ).
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
  ENDMETHOD.
ENDCLASS.

"Code to get Adobe form as Xstring:

CLASS zcl_sb_form DEFINITION
  PUBLIC
  CREATE PUBLIC .
  PUBLIC SECTION.
   METHODS get_form
      IMPORTING
        !iv_customer_id TYPE s_customer
      RETURNING
        VALUE(rv_pdf)   TYPE fpcontent .
  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS get_customer_data
      IMPORTING
        !iv_customer_id  TYPE s_customer
      EXPORTING
        !customer_detail TYPE scustom
        !bookings        TYPE ty_bookings
        !connections     TYPE ty_connections .
ENDCLASS.



CLASS zcl_sb_form IMPLEMENTATION.


  METHOD get_customer_data.

    SELECT SINGLE FROM scustom
    FIELDS *
    WHERE id = @iv_customer_id
    INTO @customer_detail.
    SELECT FROM bookings
    FIELDS *
    WHERE customid = @iv_customer_id
    INTO TABLE @bookings.
    IF lines( bookings ) > 0.
      SELECT * FROM spfli INTO TABLE @connections
      FOR ALL ENTRIES IN @bookings
      WHERE carrid = @bookings-carrid
      AND connid = @bookings-connid.
    ENDIF.

  ENDMETHOD.


  METHOD get_form.

    DATA(lv_form_name) = CONV tdsfname( 'FP_TEST_03' ).
    DATA(lv_form_fm_name) = VALUE rs38l_fnam( ).
    DATA(ls_docparams) = VALUE sfpdocparams( ).
    DATA(ls_outputparams) = VALUE sfpoutputparams( ).
    DATA(ls_formoutput) = VALUE fpformoutput( ).
* Get data
    get_customer_data(
    EXPORTING
    iv_customer_id = iv_customer_id
    IMPORTING
    customer_detail = DATA(customer)
    bookings = DATA(bookings)
    connections = DATA(connections) ).
* get name of the generated function module
    TRY.
        CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
          EXPORTING
            i_name     = lv_form_name
          IMPORTING
            e_funcname = lv_form_fm_name.
      CATCH cx_fp_api INTO DATA(lx_fp_api).
        MESSAGE ID lx_fp_api->msgid TYPE lx_fp_api->msgty
        NUMBER lx_fp_api->msgno
        WITH lx_fp_api->msgv1 lx_fp_api->msgv2
        lx_fp_api->msgv3 lx_fp_api->msgv4.
        RETURN.
    ENDTRY.
* Set output parameters and open spool job
    ls_outputparams-nodialog = 'X'. " no print preview
    ls_outputparams-getpdf = 'X'. " request PDF
    CALL FUNCTION 'FP_JOB_OPEN'
      CHANGING
        ie_outputparams = ls_outputparams
      EXCEPTIONS
        cancel          = 1
        usage_error     = 2
        system_error    = 3
        internal_error  = 4
        OTHERS          = 5.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      RETURN.
    ENDIF.
* Now call the generated function module
    CALL FUNCTION lv_form_fm_name
      EXPORTING
        /1bcdwb/docparams  = ls_docparams
        customer           = customer
        bookings           = bookings
        connections        = connections
      IMPORTING
        /1bcdwb/formoutput = ls_formoutput
      EXCEPTIONS
        usage_error        = 1
        system_error       = 2
        internal_error     = 3
        OTHERS             = 4.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      RETURN.
    ENDIF.
* Close spool job
    CALL FUNCTION 'FP_JOB_CLOSE'
      EXCEPTIONS
        usage_error    = 1
        system_error   = 2
        internal_error = 3
        OTHERS         = 4.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      RETURN.
    ENDIF.
    rv_pdf = ls_formoutput-pdf.
  ENDMETHOD.
ENDCLASS.
