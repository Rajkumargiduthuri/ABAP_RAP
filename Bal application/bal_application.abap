"What Is Application Log (BAL) in SAP?
"The SAP Application Log is a cross-application framework for storing, retrieving, and displaying messages generated during program execution. Think of it as a structured message journal your application writes to at runtime.

"Each log entry is organized around three key identifiers:

"Object: A high-level grouping representing a functional area or application.
"Subobject: A finer grouping within an object.
"External ID: A free-form string you provide at runtime to tie a log to a specific business document key.
"Log entries are persisted in database tables like BALHDR (log header) and BALDAT (log data). You can view all logs using transaction SLG1, filtering by object, subobject, external ID, date, or user. SLG1 gives you a structured view of messages with severity indicators (Status, Warning, Error, Abort), timestamps, and user info.

"Application logs are used extensively across SAP for background job results, IDoc/BAPI interface processing, data migration runs, and 
"custom business process event tracking.

"In ABAP Cloud, SAP provides a clean object-oriented API for application logging through the CL_BALI_* and XCO_CP_BAL class families, which is what we use here.
"The Goal
"We have a Billing Document RAP app with a header and item entity. Every time a billing item is created or a field is changed (material, quantity, amount, UOM, currency), we want to write an application log entry and surface those entries as a Change Log tab on the item object page in Fiori Elements.

"This solution is verified to work on S/4HANA 2023.

"Steps to Implement Application Log
"Step 1: Create the Application Log Object via ADT
"This is a prerequisite before writing any code. In classic ABAP you would use transaction SLG0 for this. In ABAP Cloud / BTP development, you create the log object directly from ADT.

"In Eclipse ADT: File > New > Other > ABAP > Application Log Object

"Create the following:

"Object: ZBILL_ITEM - "Billing Item Log"
"Subobject: ZCHANGES under ZBILL_ITEM - "Item Field Changes"

"Activate both before moving on. Without this step, the CL_BALI_* write calls will throw a CX_BALI_RUNTIME exception at runtime.


"Step 2: Add with additional save to the Behavior Definition
"Our app is a managed RAP BO. In a pure managed scenario, the framework handles all database persistence automatically and there is no saver class.

"To write application logs during the save sequence, we need a hook into that process, and that is exactly what with additional save provides.

"Adding this keyword to the header behavior node tells the RAP framework to generate a 
"local saver class LSC_ZSAC_I_BILL_HEADER and call its save_modified method after the managed save completes.
"This method is where we will write our BALI log entries in Step 9.

"Add with additional save at the beginning of the BDEF as shown below:

managed with additional save implementation in class ZBP_SAC_I_BILL_HEADER unique;
strict ( 2 );
with draft;

"Once you activate the BDEF and adjust the implementation class through quick fix,
"ADT will create the local saver class LSC_ZSAC_I_BILL_HEADER inside the behavior implementation class ZBP_SAC_I_BILL_HEADER.
"We will implement its save_modified method in Step 9.

"Step 3: Define the Custom Entity for Log Display
"Log entries don't live in a transparent table. They come from the BALI framework tables at runtime, so we can't use a standard CDS view entity. 
"We use a custom entity instead, which delegates data retrieval to a query provider class.

"If custom entities are new to you, I covered them in detail in my RAP series: SAP RAP Custom Entity. 
"The key takeaway from that blog: create the query class first, because the custom entity CDS validates its existence on activation.

@EndUserText.label: 'Billing Item Application Log'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_BILL_ITEM_LOG_QUERY'
@UI: {
  headerInfo: {
    typeName:       'Log Entry',
    typeNamePlural: 'Log Entries'
  }
}
define custom entity ZSAC_C_BILL_ITEM_LOG {

  @UI.lineItem: [{ position: 10, label: 'Bill ID' }]
  key BillId      : abap.char(10);

  @UI.lineItem: [{ position: 20, label: 'Item No' }]
  key ItemNo      : abap.numc(6);

  " Running counter used as sequence key - no business meaning
  @UI.lineItem: [{ position: 30, label: 'Log No' }]
  key ItemNumber  : abap.int4;

  @UI.lineItem: [{ position: 40, label: 'Message', importance: #HIGH }]
  MessageText     : abap.char(200);

  @UI.lineItem: [{ position: 50, label: 'Type' }]
  Severity        : abap.char(1);

  @UI.lineItem: [{ position: 60, label: 'Changed At' }]
  ChangedAt       : timestampl;

  @UI.lineItem: [{ position: 70, label: 'Changed By' }]
  ChangedBy       : syuname;

}
"All SELECT requests on this custom entity are routed to the class ZCL_BILL_ITEM_LOG_QUERY. 
"The composite key BillId + ItemNo + ItemNumber ensures each row is uniquely identifiable, where ItemNumber is a runtime sequence counter.

"We define this entity before the transactional view because Step 4 will reference it in an association, and the target object must exist at activation time.

"Step 4: Add the Association to the Item Transactional View
"With the custom entity in place, we can add the _AppLog association to the item transactional CDS view.

@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactional View for Bill Doc Item'
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
@VDM.viewType: #TRANSACTIONAL
define view entity ZSAC_I_BILL_ITEM
  as select from zsac_bill_item
  association        to parent zsac_i_bill_header as _Header on  $projection.BillId = _Header.BillId
  association [0..*] to ZSAC_C_BILL_ITEM_LOG      as _AppLog on  $projection.BillId = _AppLog.BillId
                                                             and $projection.ItemNo = _AppLog.ItemNo

{
  key BillId,
  key ItemNo,
      MaterialId,
      Description,
      Quantity,
      ItemAmount,
      Currency,
      Uom,
      @Semantics.user.createdBy: true
      CreatedBy          as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      CreateDat          as CreateDat,
      @Semantics.user.lastChangedBy: true
      LastChangedBy      as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangeDat      as LastChangeDat,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      LocalLastChangeDat as LocalLastChangeDat,

      _Header,
      _AppLog
}
"The [0..*] cardinality means one item can have many log entries. 
"Both BillId and ItemNo are used in the join condition so the association is correctly scoped per item. 
"The association must be projected in the field list for the OData layer to resolve it.

"This brings to a question - Why did we use association instead of composition to display list items of logs? Think about it.

"Step 5: Expose _AppLog in the Consumption View
"The transactional view holds the association, but the consumption view is what the OData service actually projects. 
"If _AppLog is not carried forward here, the service will have no knowledge of it and the facet in the metadata extension will not resolve.

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view for bill doc item'
@VDM.viewType: #CONSUMPTION
@Metadata.allowExtensions: true
define view entity zsac_c_bill_item
  as projection on zsac_i_bill_item
{
  key BillId,
  key ItemNo,
      MaterialId,
      Description,
      Quantity,
      ItemAmount,
      Currency,
      Uom,
      CreatedBy,
      CreateDat,
      LastChangedBy,
      LastChangeDat,
      LocalLastChangeDat,

      _Header : redirected to parent zsac_c_bill_header,
      _AppLog
}
"No redirection is needed for _AppLog unlike _Header. Redirections apply only to associations that point to other RAP BO nodes within the same composition tree.
"ZSAC_C_BILL_ITEM_LOG is a standalone custom entity, so it passes through as-is.

"Step 6: Add the Change Log Facet via Metadata Extension
"We add a second facet to the item object page that renders the log entries as a table.

@Metadata.layer: #CORE
@UI: {
  headerInfo: { typeName: 'Billing Document Header',
                typeNamePlural: 'Billing Documents',
                title: { type: #STANDARD, label: 'Billing Document', value: 'BillId' },
                description: { label: 'Billing Document Item', value: 'ItemNo' } }
              }
annotate entity ZSAC_C_Bill_Item with
{
  @UI.facet: [ {
    id:       'BillingDocItem',
    purpose:  #STANDARD,
    type:     #IDENTIFICATION_REFERENCE,
    label:    'Item',
    position: 10
  },
  {
      id:            'idAppLog',
      type:          #LINEITEM_REFERENCE,
      label:         'Change Log',
      position:      20,
      targetElement: '_AppLog'
    }]

  @UI.hidden: true
  BillId;

  @EndUserText.label: 'Item Number'
  @UI: {
    lineItem:       [ { position: 20 } ],
    identification: [ { position: 20 } ],
    selectionField: [ { position: 20 } ]
  }
  ItemNo;

  @EndUserText.label: 'Material'
  @UI: {
    lineItem:       [ { position: 30 } ],
    identification: [ { position: 30 } ]
  }
  MaterialId;

  @EndUserText.label: 'Description'
  @UI: {
    lineItem:       [ { position: 40 } ],
    identification: [ { position: 40 } ]
  }
  Description;

  @EndUserText.label: 'Quantity'
  @UI: {
    lineItem:       [ { position: 50 } ],
    identification: [ { position: 50 } ]
  }
  Quantity;

  @EndUserText.label: 'Unit of Measure'
  @UI: {
    lineItem:       [ { position: 60 } ],
    identification: [ { position: 60 } ]
  }
  Uom;

  @EndUserText.label: 'Amount'
  @UI: {
    lineItem:       [ { position: 70 } ],
    identification: [ { position: 70 } ]
  }
  ItemAmount;

  @EndUserText.label: 'Currency'
  @UI: {
    lineItem:       [ { position: 80 } ],
    identification: [ { position: 80 } ]
  }
  Currency;
}
#LINEITEM_REFERENCE with targetElement: '_AppLog' tells Fiori Elements to render the association as an embedded table section. 

"Step 7: Implement the Query Provider Class
"This class is called by the framework every time the Change Log tab loads. 
"It reads entries from the BALI tables using the XCO_CP_BAL API, which is the Cloud-ready replacement for the classic BAL_DB_SEARCH and BAL_LOG_MSG_READ function modules.

CLASS zcl_bill_item_log_query DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

ENDCLASS.

CLASS zcl_bill_item_log_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    " Result table typed against the custom entity structure
    DATA: lv_bill_id TYPE char10,
          lv_item_no TYPE numc06,
          lt_result  TYPE TABLE OF zsac_c_bill_item_log.

    " Read paging parameters sent by Fiori Elements
    DATA(lv_top)  = io_request->get_paging( )->get_page_size( ).
    IF lv_top < 0.
      lv_top = 1.
    ENDIF.

    DATA(lv_skip) = io_request->get_paging( )->get_offset( ).
    DATA(lt_sort) = io_request->get_sort_elements( ).

    TRY.

        " Extract OData filter conditions as ranges
        TRY.
            DATA(lt_ranges) = io_request->get_filter( )->get_as_ranges( ).
          CATCH cx_rap_query_filter_no_range.
            "handle exception
        ENDTRY.

        " Read BillId from filter - sent automatically by the OData layer
        " based on the association join condition
        READ TABLE lt_ranges WITH KEY name = 'BILLID'
          INTO DATA(ls_bill_filter).
        IF sy-subrc = 0.
          lv_bill_id = ls_bill_filter-range[ 1 ]-low.
        ENDIF.

        " Read ItemNo from filter - same reason as above
        READ TABLE lt_ranges WITH KEY name = 'ITEMNO'
          INTO DATA(ls_item_filter).
        IF sy-subrc = 0.
          lv_item_no = ls_item_filter-range[ 1 ]-low.
        ENDIF.

        " Guard: if either key is missing, return empty result
        " Querying without document keys would be meaningless and expensive
        IF lv_bill_id IS INITIAL OR lv_item_no IS INITIAL.
          io_response->set_total_number_of_records( 0 ).
          io_response->set_data( lt_result ).
          RETURN.
        ENDIF.

        " Build external ID in the same format used during log writing
        " Format: -  e.g. BILL0001-000010
        DATA(lv_ext_id) = CONV cl_bali_header_setter=>ty_external_id(
                            |{ lv_bill_id }-{ lv_item_no }| ).

        " Build XCO filters to scope the BALI query to this specific item
        DATA(lo_object_filter)    = xco_cp_bal=>log_filter->object(
          xco_cp_abap_sql=>constraint->equal( 'ZBILL_ITEM' ) ).

        DATA(lo_subobject_filter) = xco_cp_bal=>log_filter->subobject(
          xco_cp_abap_sql=>constraint->equal( 'ZCHANGES' ) ).

        DATA(lo_ext_id_filter)    = xco_cp_bal=>log_filter->external_id(
          xco_cp_abap_sql=>constraint->equal( lv_ext_id ) ).

        " Fetch all matching log handles from the database
        DATA(lt_xco_logs) = xco_cp_bal=>for->database( )->logs->where(
          VALUE #(
            ( lo_object_filter    )
            ( lo_subobject_filter )
            ( lo_ext_id_filter    )
          ) )->get( ).

        " Counter used as the ItemNumber key field to ensure row uniqueness
        DATA(lv_counter) = 0.

        " Outer loop: each handle is a separate log header (one per save operation)
        LOOP AT lt_xco_logs INTO DATA(lo_xco_log).

          " Inner loop: each log header can have multiple message items
          LOOP AT lo_xco_log->messages->all->get( ) INTO DATA(lo_msg).
            lv_counter += 1.

            APPEND VALUE #(
              billid      = lv_bill_id
              itemno      = lv_item_no
              itemnumber  = lv_counter                              " Sequence key
              messagetext = CONV #( lo_msg->value-message->get_text( ) )
              severity    = lo_msg->value-message->value            " S/W/E/A
              changedat   = lo_msg->value-timestamp->value
              changedby   = lo_xco_log->header->get_created_by( )->name " Log creator
            ) TO lt_result.

          ENDLOOP.
        ENDLOOP.

        " set_total_number_of_records is required - Fiori Elements uses it for pagination
        IF io_request->is_total_numb_of_rec_requested( ).
          io_response->set_total_number_of_records( lines( lt_result ) ).
          io_response->set_data( lt_result ).
        ENDIF.

      CATCH cx_bali_runtime cx_rap_query_provider INTO DATA(lx).
        " Swallow exceptions silently - log display failure must not crash the UI

    ENDTRY.

  ENDMETHOD.

ENDCLASS.
"The filter names BILLID and ITEMNO must be in uppercase and match the CDS field names exactly. These are passed automatically by the OData layer based on the association join condition, so you don't need to send them manually from the UI.

"Step 8: Implement the Log Writer Utility Class
"All BALI write logic lives in a dedicated static utility class. This keeps the behavior saver lean and makes the writer reusable across other parts of the app.

CLASS zcl_bill_item_log_writer DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Static method - no instance needed, called directly via class=>method
    CLASS-METHODS write_log
      IMPORTING
        iv_bill_id  TYPE char10
        iv_item_no  TYPE num06
        iv_message  TYPE string
        iv_severity TYPE if_bali_constants=>ty_severity.

ENDCLASS.

CLASS zcl_bill_item_log_writer IMPLEMENTATION.

  METHOD write_log.

    TRY.

      " Build external ID: same format used in the query provider
      " This is how the reader finds the log entries for a specific item
      DATA(lv_external_id) = CONV cl_bali_header_setter=>ty_external_id(
                               |{ iv_bill_id }-{ iv_item_no }| ).

      " Create a new log instance with header tied to our object/subobject
      DATA(lo_log) = cl_bali_log=>create_with_header(
        header = cl_bali_header_setter=>create(
          object      = 'ZBILL_ITEM'   " Must match ADT application log object
          subobject   = 'ZCHANGES'     " Must match ADT application log subobject
          external_id = lv_external_id ) ).

      " Create a free-text message item with the provided severity and text
      DATA(lo_item) = cl_bali_free_text_setter=>create(
        severity = iv_severity
        text     = CONV cl_bali_free_text_setter=>ty_text( iv_message ) ).

      " Detail level 1 makes the message visible in standard SLG1 display
      lo_item->set_detail_level( '1' ).
      lo_log->add_item( lo_item ).

      " Persist the log to the database immediately
      cl_bali_log_db=>get_instance( )->save_log( log = lo_log ).

    CATCH cx_bali_runtime INTO DATA(lx).
      " Never re-raise here - a logging failure must not break the document save
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
"Each call to write_log creates and saves one log entry. The external ID format - must be identical to what the query provider builds in Step 7, otherwise reads will return nothing.

"Step 9: Implement the Behavior Saver
"save_modified fires after all validations pass and the managed framework has completed its own database persistence. This is the right place to write audit entries, because at this point we know the save will succeed.

"Open the behavior implementation class ZBP_SAC_I_BILL_HEADER in ADT and navigate to the Local Types tab. You will find LSC_ZSAC_I_BILL_HEADER already generated there from Step 2. Implement its save_modified method as follows:

CLASS lsc_zsac_i_bill_header DEFINITION
  INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zsac_i_bill_header IMPLEMENTATION.

  METHOD save_modified.

    " ---------------------------------------------------------------
    " Handle CREATE: log a summary message for each new item
    " ---------------------------------------------------------------
    LOOP AT create-zsac_r_bill_item INTO DATA(ls_created).
      zcl_bill_item_log_writer=>write_log(
        iv_bill_id  = ls_created-billid
        iv_item_no  = ls_created-itemno
        iv_message  = |Item created: Material { ls_created-materialid }| &&
                      | Qty { ls_created-quantity } { ls_created-uom }| &&
                      | Amount { ls_created-itemamount } { ls_created-currency }|
        iv_severity = if_bali_constants=>c_severity_status ).
    ENDLOOP.

    " ---------------------------------------------------------------
    " Handle UPDATE: compare old vs new, log only what actually changed
    " ---------------------------------------------------------------
    LOOP AT update-zsac_r_bill_item INTO DATA(ls_update).

      DATA(lv_bill_id) = ls_update-billid.
      DATA(lv_item_no) = ls_update-itemno.

      " Read the current database state (pre-save values) for comparison
      " SELECT on the table directly - not the CDS view - to get raw old values
      SELECT SINGLE * FROM zsac_bill_item
        WHERE bill_id = @lv_bill_id
          AND item_no = @lv_item_no
        INTO @DATA(ls_old).

      IF sy-subrc <> 0.
        CONTINUE. " Item not found - skip silently
      ENDIF.

      " Collect all change messages into a local table before writing
      DATA lt_messages TYPE string_table.

      " Check each field: %control tells us which fields were included
      " in this particular save. We only log fields that were both
      " touched (mk-on) AND actually have a different value.

      IF ls_update-%control-materialid = if_abap_behv=>mk-on
        AND ls_old-material_id <> ls_update-materialid.
        APPEND |Material changed: { ls_old-material_id } -> { ls_update-materialid }|
          TO lt_messages.
      ENDIF.

      IF ls_update-%control-quantity = if_abap_behv=>mk-on
        AND ls_old-quantity <> ls_update-quantity.
        APPEND |Quantity changed: { ls_old-quantity } -> { ls_update-quantity } { ls_old-uom }|
          TO lt_messages.
      ENDIF.

      IF ls_update-%control-itemamount = if_abap_behv=>mk-on
        AND ls_old-item_amount <> ls_update-itemamount.
        APPEND |Amount changed: { ls_old-item_amount } -> { ls_update-itemamount } { ls_old-currency }|
          TO lt_messages.
      ENDIF.

      IF ls_update-%control-uom = if_abap_behv=>mk-on
        AND ls_old-uom <> ls_update-uom.
        APPEND |UoM changed: { ls_old-uom } -> { ls_update-uom }|
          TO lt_messages.
      ENDIF.

      IF ls_update-%control-currency = if_abap_behv=>mk-on
        AND ls_old-currency <> ls_update-currency.
        APPEND |Currency changed: { ls_old-currency } -> { ls_update-currency }|
          TO lt_messages.
      ENDIF.

      " Write one log entry per changed field
      LOOP AT lt_messages INTO DATA(lv_msg).
        zcl_bill_item_log_writer=>write_log(
          iv_bill_id  = lv_bill_id
          iv_item_no  = lv_item_no
          iv_message  = lv_msg
          iv_severity = if_bali_constants=>c_severity_status ).
      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
T"he %control check combined with the old/new value comparison ensures only genuinely changed fields are logged. Without the %control check, you risk logging fields the user never touched if they happen to carry the same value in the update structure.

"Step 10: Expose ZSAC_C_BILL_ITEM_LOG in the Service Definition
"The service definition controls what is visible via OData. Even though _AppLog is now part of the consumption view, the custom entity itself must be explicitly exposed here. Without this line, the OData layer cannot resolve the association at runtime and the Change Log tab will return an error.

@EndUserText.label: 'Service Def for Billing Document'
define service Zsac_ui_bill_head {
  expose zsac_c_bill_headtp   as BillingDocumentHeader;
  expose zsac_c_bill_itemtp   as BillingDocumentItem;
  expose ZSAC_C_BILL_ITEM_LOG as BillingDocumentItemLog;
}
"This is a commonly missed step. The association in the consumption view tells the OData layer how to navigate to the log entity, but the service definition is what tells it that the entity exists in this service. Both are needed.

"The Result in Fiori Elements
"Once all pieces are activated, open any billing item in your app. The object page will have two tabs:

"Item: the standard identification facet
"Change Log: a table showing every log entry for that specific item, with message text, severity, timestamp, and user
"Object page

"Application Log records

"You can also cross-check in SLG1 using object ZBILL_ITEM, subobject ZCHANGES, and external ID -.

"Application log for create record

"Same entries, classic GUI view, useful for support and basis teams.

"Application Log - BAL in GUI
