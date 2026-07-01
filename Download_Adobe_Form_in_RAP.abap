"D𝗼𝘄𝗻𝗹𝗼𝗮𝗱𝗶𝗻𝗴 𝗔𝗱𝗼𝗯𝗲 𝗳𝗼𝗿𝗺𝘀 𝗼𝗿 𝗮𝗻𝘆 𝗳𝗶𝗹𝗲𝘀 𝗶𝗻 𝗥𝗔𝗣.  
"if you’ve tried this before, you might have noticed that methods like 𝗚𝗨𝗜_𝗗𝗢𝗪𝗡𝗟𝗢𝗔𝗗 or 𝗰𝗹_𝗴𝘂𝗶_𝗳𝗿𝗼𝗻𝘁𝗲𝗻𝗱_𝘀𝗲𝗿𝘃𝗶𝗰𝗲𝘀=>𝗴𝘂𝗶_𝗱𝗼𝘄𝗻𝗹𝗼𝗮𝗱 don’t work in RAP. 
"So, what’s the alternative? This can be achieved using streams (file upload) in RAP, combined with some additional logic. 
"Here are the two approaches I followed in my example: 

"1. 𝗖𝗿𝗲𝗮𝘁𝗲 𝗮𝗻 𝗮𝗰𝘁𝗶𝗼𝗻 to populate your stream fields with form data. 
"2. Use a 𝘃𝗶𝗿𝘁𝘂𝗮𝗹 𝗲𝗹𝗲𝗺𝗲𝗻𝘁 to fill your stream fields (not recommended, as it may trigger your Adobe form method multiple times). 
"Note: Ensure that your stream fields (attachment fields) are set to read-only,since it's getting filled through our logic. For the below Example I’ve created on OdataV4 – UI

"1. create virtual element in Cds projectoion view
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Project view of agreement'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZRAJ_CDS_C_AGREEMENT
  provider contract transactional_query
  as projection on zraj_cds_agreement
{
......
  /*-----------------------------------------------------------
              Virtual Field for Base64 PDF content
              RAP calculates this via ZRKCL_VIRTUAL_CALC class.
            -----------------------------------------------------------*/
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZRKCL_VIRTUAL_CALC'
          @ObjectModel.virtualElement: true
  virtual attach : abap.string(0),
}

"2.implement the class and fetch the pdf output as base 64 format map to crresponding fields

"virtual element class implementation
CLASS zrkcl_virtual_calc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_sadl_exit .
    INTERFACES if_sadl_exit_calc_element_read .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zrkcl_virtual_calc IMPLEMENTATION.


  METHOD if_sadl_exit_calc_element_read~calculate.
    " internal table for virtual elements in projection view
    DATA: lt_virtual TYPE TABLE OF zraj_cds_c_agreement,
          lv_base64  TYPE string.

    "Move original Rap data into a working virtual table
    lt_virtual = CORRESPONDING #( it_original_data ).

    "Loop over each row to calculate the virtual element (Base64 PDF)
    LOOP AT lt_virtual ASSIGNING FIELD-SYMBOL(<lfa_virtual>).
      DATA(lv_prnum) = <lfa_virtual>-prnum.

      "creating new instance of adobe form handler class
      DATA(lo_inst) = NEW zrkcl_adobeform( ).

      "call adobe form to generator to get raw PDF (Xstring)
      DATA(rv_pdf) = lo_inst->get_data( iv_prnmun = lv_prnum ).

      "convert PDF(Xstring) -> base64 string, required for RAP Download media
      CALL FUNCTION 'SCMS_BASE64_ENCODE_STR'
        EXPORTING
          input  = rv_pdf
        IMPORTING
          output = lv_base64.

      " Assign Base64 string to virtual element field
      <lfa_virtual>-attach = lv_base64.

    ENDLOOP.

    " Move calculated data back to RAP consumption structure
    ct_calculated_data = CORRESPONDING #( lt_virtual ).

  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
  ENDMETHOD.
ENDCLASS.


CLASS zrkcl_adobeform DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS: get_data
      IMPORTING iv_prnmun     TYPE /agri/fmprnum
      RETURNING VALUE(rv_pdf) TYPE xstring.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


"To retrieve the Adobe Form as an XSTRING,
"I implemented a dedicated ABAP class responsible for generating and returning the PDF content. 
"The implementation code is as follows:

CLASS zrkcl_adobeform IMPLEMENTATION.
  METHOD get_data.

    "adobe form name
    DATA(lv_formname) = CONV tdsfname( 'ZRK_PR_F_ADOBE' ).

    " Name of the generated function module for the form
    DATA(lv_form_fm_name) = VALUE rs38l_fnam( ).

    " Structures for Adobe Form parameters
    DATA(ls_docparams)    = VALUE sfpdocparams( ).
    DATA(ls_outputparams) = VALUE sfpoutputparams( ).
    DATA(ls_formoutput)   = VALUE fpformoutput( ).

    "get generated function module name
    TRY.
        CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
          EXPORTING
            i_name     = lv_formname      "form Name
          IMPORTING
            e_funcname = lv_form_fm_name  "generated FM name
*           e_interface_type    =
*           ev_funcname_inbound =
          .
      CATCH cx_fp_api_repository INTO DATA(ls_api).

        " Handle form API errors
        MESSAGE ID ls_api->msgid TYPE ls_api->msgty
                NUMBER ls_api->msgno
                WITH ls_api->msgv1 ls_api->msgv2
                     ls_api->msgv3 ls_api->msgv4.
      CATCH cx_fp_api_usage.
      CATCH cx_fp_api_internal.
    ENDTRY.

    " Prepare Output Parameters for PDF Generation
    ls_outputparams-nopreview = abap_true.
    ls_outputparams-getpdf = abap_true.

    "open adobe form spool job
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
      " Display error message and exit
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      RETURN.
    ENDIF.

    "call generated adobe form FUnction module
    CALL FUNCTION lv_form_fm_name
      EXPORTING
*       /1BCDWB/DOCPARAMS  =
        prnum              = iv_prnmun
      IMPORTING
        /1bcdwb/formoutput = ls_formoutput
      EXCEPTIONS
        usage_error        = 1
        system_error       = 2
        internal_error     = 3
        OTHERS             = 4.
    IF sy-subrc NE 0.
      " Errors during form rendering
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      RETURN.
    ENDIF.

    "close adobe form spool job
    CALL FUNCTION 'FP_JOB_CLOSE'
      EXCEPTIONS
        usage_error    = 1
        system_error   = 2
        internal_error = 3
        OTHERS         = 4.

    IF sy-subrc <> 0.
      " Handle spool closing issues
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      RETURN.
    ENDIF.

    "return base 64 string to virtual element
    rv_pdf = ls_formoutput-pdf.         "Base 64 encoded pdf


  ENDMETHOD.

ENDCLASS.

"Right click on web app and click on open guided development.
"We need custom action to be implemented.
"Click on add a custom action.
"Add necessary details and click on insert code snippet it will be added to manifest.
"json, it will add one more controller, where we can add our custom logic.

"To handle multi-PDF downloads from the List Report, I implemented a custom action in the controller extension. When the user selects one or more rows, a confirmation popup is shown using MessageBox.confirm. After the user confirms, the extension reads each selected entity via the OData model and retrieves the attach virtual element, which contains the Adobe Form as a Base64 string. The code then converts the Base64 into a PDF Blob and automatically triggers a download for each sales document, generating individual files such as Sales_Document_<VBELN>.pdf. This approach provides a smooth, scalable way to download multiple Adobe Forms directly from the Fiori UI without additional backend endpoints.
"EXTENSION Controller code

sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox"
], function (MessageToast, MessageBox) {
    'use strict';

    return {
        //if the attchment field hidden in cds view level we are externally fetching the attch field in 
        // onInit: function(oEvent) {
        //    var oSrc = oEvent.getSource();
        //    var oView = this.getView();
        //    var oTableId = oView.createId()
        // }, 
        pdf: function (oEvent) {
            var oController = this;
            var oExtensionAPI = oController.extensionAPI;
            if (!oExtensionAPI) {
                MessageToast.show("Extension API not available");
                return;
            }

            var aSelectedRows = oExtensionAPI.getSelectedContexts();
            // FIX: check .length property of the array, not the array itself
            if (!aSelectedRows || aSelectedRows.length === 0) {
                MessageToast.show("Please select at least one row.");
                return;
            }

            // Ask user for confirmation
            MessageBox.confirm("Do you want to download the selected PDF(s)?", {
                title: "Confirm Download",
                actions: [MessageBox.Action.OK, MessageBox.Action.CANCEL],
                onClose: function (oAction) { // FIX: Casing change (OAction -> oAction)
                    if (oAction !== MessageBox.Action.OK) {
                        return;
                    }

                    var oView = oController.getView();
                    var oModel = oView ? oView.getModel() : null;
                    if (!oModel) {
                        MessageToast.show("OData Model not Found.");
                        return;
                    }

                    // Loop begins safely here

                    aSelectedRows.forEach( ocntxt => {
                        var odata = ocntxt.getObject();
                        var base64String = odata.attach; // FIX: matching variable name casing
                                if (!base64String) {
                                    MessageToast.show("No PDF attachment found for row.");
                                    return;
                                }

                                try {
                                    // Convert Base64 → binary
                                    var binaryString = atob(base64String); // FIX: variable casing
                                    var len = binaryString.length;
                                    var bytes = new Uint8Array(len);

                                    for (var i = 0; i < len; i++) {
                                        bytes[i] = binaryString.charCodeAt(i);
                                    }

                                    // Create Blob for PDF download
                                    var blob = new Blob([bytes], { type: "application/pdf" });
                                    var link = document.createElement("a");
                                    link.href = URL.createObjectURL(blob);

                                    // File name format
                                    link.download = "Agreement_" + (odata.prnum || "Download") + ".pdf";

                                    // Trigger download safely
                                    document.body.appendChild(link);
                                    link.click();
                                    document.body.removeChild(link);
                                    URL.revokeObjectURL(link.href);

                                } catch (e) {
                                    MessageToast.show("Conversion failed for PR: " + odata.prnum);
                                }
                            }

                    )

          ""below commented code we are triggering read serivice mulitple time 
                    // aSelectedRows.forEach(function (oContext) {
                    //     var sPath = oContext.getPath();

                    //     oModel.read(sPath, {
                    //         success: function (odata) { // FIX: normalized casing to lower-case 'odata'

                    //             var base64String = odata.attach; // FIX: matching variable name casing
                    //             if (!base64String) {
                    //                 MessageToast.show("No PDF attachment found for row.");
                    //                 return;
                    //             }

                    //             try {
                    //                 // Convert Base64 → binary
                    //                 var binaryString = atob(base64String); // FIX: variable casing
                    //                 var len = binaryString.length;
                    //                 var bytes = new Uint8Array(len);

                    //                 for (var i = 0; i < len; i++) {
                    //                     bytes[i] = binaryString.charCodeAt(i);
                    //                 }

                    //                 // Create Blob for PDF download
                    //                 var blob = new Blob([bytes], { type: "application/pdf" });
                    //                 var link = document.createElement("a");
                    //                 link.href = URL.createObjectURL(blob);

                    //                 // File name format
                    //                 link.download = "Agreement_" + (odata.prnum || "Download") + ".pdf";

                    //                 // Trigger download safely
                    //                 document.body.appendChild(link);
                    //                 link.click();
                    //                 document.body.removeChild(link);
                    //                 URL.revokeObjectURL(link.href);

                    //             } catch (e) {
                    //                 MessageToast.show("Conversion failed for PR: " + odata.prnum);
                    //             }
                    //         },
                    //         error: function () {
                    //             MessageToast.show("Error fetching PDF data.");
                    //         }
                    //     }); 
                    // });
                }
            });
        }
    };
});


