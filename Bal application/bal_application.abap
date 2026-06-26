What Is Application Log (BAL) in SAP?
The SAP Application Log is a cross-application framework for storing, retrieving, and displaying messages generated during program execution. Think of it as a structured message journal your application writes to at runtime.

Each log entry is organized around three key identifiers:

Object: A high-level grouping representing a functional area or application.
Subobject: A finer grouping within an object.
External ID: A free-form string you provide at runtime to tie a log to a specific business document key.
Log entries are persisted in database tables like BALHDR (log header) and BALDAT (log data). You can view all logs using transaction SLG1, filtering by object, subobject, external ID, date, or user. SLG1 gives you a structured view of messages with severity indicators (Status, Warning, Error, Abort), timestamps, and user info.

Application logs are used extensively across SAP for background job results, IDoc/BAPI interface processing, data migration runs, and custom business process event tracking.

In ABAP Cloud, SAP provides a clean object-oriented API for application logging through the CL_BALI_* and XCO_CP_BAL class families, which is what we use here.
The Goal
We have a Billing Document RAP app with a header and item entity. Every time a billing item is created or a field is changed (material, quantity, amount, UOM, currency), we want to write an application log entry and surface those entries as a Change Log tab on the item object page in Fiori Elements.

This solution is verified to work on S/4HANA 2023.

Steps to Implement Application Log
Step 1: Create the Application Log Object via ADT
This is a prerequisite before writing any code. In classic ABAP you would use transaction SLG0 for this. In ABAP Cloud / BTP development, you create the log object directly from ADT.

In Eclipse ADT: File > New > Other > ABAP > Application Log Object

Create the following:

Object: ZBILL_ITEM - "Billing Item Log"
Subobject: ZCHANGES under ZBILL_ITEM - "Item Field Changes"

Activate both before moving on. Without this step, the CL_BALI_* write calls will throw a CX_BALI_RUNTIME exception at runtime.


Step 2: Add with additional save to the Behavior Definition
Our app is a managed RAP BO. In a pure managed scenario, the framework handles all database persistence automatically and there is no saver class.

To write application logs during the save sequence, we need a hook into that process, and that is exactly what with additional save provides.

Adding this keyword to the header behavior node tells the RAP framework to generate a local saver class LSC_ZSAC_I_BILL_HEADER and call its save_modified method after the managed save completes. This method is where we will write our BALI log entries in Step 9.

Add with additional save at the beginning of the BDEF as shown below:

