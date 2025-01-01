CLASS zzcl_job_fi002 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object .
    INTERFACES if_apj_rt_exec_object .
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zzcl_job_fi002 IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    DATA  et_parameters TYPE if_apj_rt_exec_object=>tt_templ_val  .

    et_parameters = VALUE #(
        ( selname = 'TSTMPL'
          kind = if_apj_dt_exec_object=>parameter
          sign = 'I'
          option = 'EQ'
          low = '20241216021000.4605050' )
      ).
    TRY.
        if_apj_rt_exec_object~execute( it_parameters = et_parameters ).
      CATCH cx_root INTO DATA(job_scheduling_exception).
        DATA(lv_text) = job_scheduling_exception->get_longtext( ).
    ENDTRY.
  ENDMETHOD.

  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
      ( selname        = 'NUMBER'
        kind           = if_apj_dt_exec_object=>select_option
        datatype       = 'C'
        length         = 50
        param_text     = '交易流水号'
        changeable_ind = abap_true )

      ( selname        = 'PROCESS'
        kind           = if_apj_dt_exec_object=>parameter
        datatype       = 'C'
        length         = 1
        param_text     = 'JOB处理方式(1前台;2后台)'
        changeable_ind = abap_true
        mandatory_ind  = abap_true  )
       ).


  ENDMETHOD.

  METHOD if_apj_rt_exec_object~execute.


    DATA:lv_stamp TYPE zztfi_0005-zztstmpl.
    DATA: lv_msgty    TYPE bapi_mtype,
          lv_msgtx    TYPE bapi_msg,
          lv_text     TYPE string,
          lv_severity TYPE c LENGTH 1.
    DATA:ls_request      TYPE zjournal_entry_bulk_create_req,
         lt_journalentry TYPE zjournal_entry_create_requ_tab,
         ls_journalentry TYPE zjournal_entry_create_request,
         ls_response     TYPE zjournal_entry_bulk_create_con.
    DATA:lt_gl TYPE TABLE OF zjournal_entry_create_request9,
         ls_gl TYPE zjournal_entry_create_request9.
    DATA:lt_debtor TYPE TABLE OF zjournal_entry_create_reques13,
         ls_debtor TYPE zjournal_entry_create_reques13.
    DATA:lv_dmbtr TYPE dmbtr.

    DATA:lt_md    TYPE TABLE OF zztfi_0005,
         ls_md    TYPE zztfi_0005,
         lt_mdall TYPE TABLE OF zztfi_0005.

    DATA:r_tmstmp  TYPE RANGE OF zztfi_0005-zztstmpl,
         lv_bstamp TYPE zztfi_0005-zztstmpl,
         lv_estamp TYPE zztfi_0005-zztstmpl.
    DATA:lv_process TYPE ze_job_proc.
    DATA:r_number TYPE RANGE OF zztfi_0005-transactionserialnumber.


    LOOP AT it_parameters INTO DATA(l_parameter).
      CASE l_parameter-selname.
        WHEN 'NUMBER'.
          APPEND VALUE #( sign   = l_parameter-sign
                          option = l_parameter-option
                          low    = l_parameter-low
                          high   = l_parameter-high  ) TO r_number.

        WHEN 'PROCESS'.
          lv_process = l_parameter-low.
      ENDCASE.
    ENDLOOP.

    CASE lv_process.
      WHEN '1'.
        SELECT *
          FROM zztfi_0005
         WHERE transactionserialnumber IN @r_number
           AND msgty <> 'S'
          INTO TABLE @DATA(lt_ztfi005).
      WHEN '2'.
        "没有参数，默认后台增量推送
        lv_bstamp =  zzcl_comm_tool=>get_last_execute( 'FI003' ).
        GET TIME STAMP FIELD lv_estamp.
        APPEND  VALUE #( option = 'BT'
                         sign   = 'I'
                         low    = lv_bstamp
                         high   = lv_estamp
                    ) TO r_tmstmp.

        SELECT *
          FROM zztfi_0005
         WHERE zztstmpl IN @r_tmstmp
           AND transactionserialnumber IS NOT INITIAL
          INTO TABLE @lt_ztfi005.
    ENDCASE.



    CHECK lt_ztfi005 IS NOT INITIAL.
    SORT lt_ztfi005 BY transactionserialnumber.
    DATA(lt_tmp) = lt_ztfi005.
    DELETE ADJACENT DUPLICATES FROM lt_tmp COMPARING transactionserialnumber.


    TRY.
        DATA(l_log) = cl_bali_log=>create_with_header(
             header = cl_bali_header_setter=>create( object = 'ZZ_ALO_API'
                                                     subobject = 'ZZ_ALO_API_SUB' ) ).
        "SOAP接口代理类
        DATA(destination) = cl_soap_destination_provider=>create_by_comm_arrangement(
                            comm_scenario  = 'ZZHTTP_INBOUND_API'
        ).
        DATA(proxy) = NEW zco_journal_entry_create_reque( destination = destination ).


        LOOP AT lt_tmp INTO DATA(ls_tmp).
          SELECT SINGLE accountingdocument
            FROM i_journalentry WITH PRIVILEGED ACCESS
           WHERE accountingdocumenttype = 'DZ'
             AND accountingdocumentheadertext = @ls_tmp-transactionserialnumber
             AND isreversal = ''
             AND isreversed = ''
            INTO @DATA(ls_entry).
          IF sy-subrc = 0.
            l_log->add_item( item = cl_bali_free_text_setter=>create(
             severity = if_bali_constants=>c_severity_warning
             text = CONV #( |{ ls_tmp-transactionserialnumber }已创建凭证{ ls_entry }| ) ) ).
            CONTINUE.
          ENDIF.

          CLEAR:ls_request,ls_response.
          GET TIME STAMP FIELD ls_tmp-local_last_changed_at.

          "管理货币
          SELECT SINGLE *
            FROM zztfi_0002
           WHERE zcurrency = @ls_tmp-currency
           INTO @DATA(ls_zztfi_0002).
          "银行账号&开户行&开户行账户关系维护表
          SELECT SINGLE *
            FROM zztfi_0001
           WHERE bankn = @ls_tmp-accountno
           INTO @DATA(ls_zztfi_0001).

          "过账抬头----------BEGIN----------
          "源参考凭证类别
          ls_journalentry-journal_entry-original_reference_document_ty = 'BKPFF'.
          "业务交易类别
          ls_journalentry-journal_entry-business_transaction_type = 'RFBU'.
          "凭证类别
          ls_journalentry-journal_entry-accounting_document_type = 'DZ'.
          "凭证抬头文本
          ls_journalentry-journal_entry-document_header_text  = ls_tmp-transactionserialnumber.
          "创建人
          ls_journalentry-journal_entry-created_by_user = ls_tmp-createbyname.
          "公司代码
          ls_journalentry-journal_entry-company_code = ls_zztfi_0001-bukrs.
          "凭证日期
          ls_journalentry-journal_entry-document_date   = ls_tmp-claimsuccesstime.
          "过账日期
          ls_journalentry-journal_entry-posting_date = sy-datum.
          "过账抬头----------END----------

          CLEAR:lt_gl,lt_debtor,lt_md,lv_dmbtr.
          "行项目----------BEGIN----------
          READ TABLE lt_ztfi005 TRANSPORTING NO FIELDS WITH KEY transactionserialnumber = ls_tmp-transactionserialnumber BINARY SEARCH.
          IF sy-subrc = 0.
            LOOP AT lt_ztfi005 INTO DATA(ls_ztfi005) FROM sy-tabix.
              IF ls_ztfi005-transactionserialnumber = ls_tmp-transactionserialnumber.
                lv_dmbtr = lv_dmbtr + ls_ztfi005-claimamount.

                CLEAR:ls_debtor.
                "参考凭证
                ls_debtor-reference_document_item = 1.
                "客户代码
                ls_debtor-debtor = ls_ztfi005-merchantcode.
                "备选统驭科目
                ls_debtor-altv_recncln_accts = VALUE zchart_of_accounts_item_code(
                   content = SWITCH #( ls_ztfi005-extend1
                                       WHEN '业务认领' THEN '2205020100'
                                       WHEN '财务认领' THEN '2241020000'   )
                               ).
                "交易货币金额
                ls_debtor-amount_in_transaction_currency = VALUE zamount( currency_code = ls_zztfi_0002-waers content = 0 - ls_ztfi005-claimamount  ).
                "集团货币金额
                ls_debtor-amount_in_group_currency = VALUE zamount( currency_code = ls_zztfi_0002-waers content = 0 - ls_ztfi005-claimamount  ).
                "借贷码.
                ls_debtor-debit_credit_code = 'H'.
                "凭证项目文本
                ls_debtor-document_item_text = ls_ztfi005-transactionserialnumber.
                "分配
                ls_debtor-assignment_reference = ls_ztfi005-transactionserialnumber.
                APPEND ls_debtor TO lt_debtor.

                APPEND ls_ztfi005 TO lt_md.
                DATA(ls_005) = ls_ztfi005.
              ELSE.
                EXIT.
              ENDIF.
            ENDLOOP.

            CLEAR:ls_gl.
            "总账科目
            ls_gl-glaccount     = VALUE zchart_of_accounts_item_code( content = ls_zztfi_0002-racct ).
            "交易货币金额
            ls_gl-amount_in_transaction_currency = VALUE zamount( currency_code = ls_zztfi_0002-waers content = lv_dmbtr  ).
            "集团货币金额
            ls_gl-amount_in_group_currency = VALUE zamount( currency_code = ls_zztfi_0002-waers content = lv_dmbtr  ).
            "借贷码
            ls_gl-debit_credit_code = 'S'.
            "原因代码
            ls_gl-reason_code = ls_005-paymentnaturedetail.
            "凭证项目文本
            ls_gl-document_item_text = ls_005-transactionserialnumber.
            "开户行
            ls_gl-house_bank = ls_zztfi_0001-hbkid.
            "开户行账户
            ls_gl-house_bank_account = ls_zztfi_0001-hktid.
            .
            ls_gl-account_assignment = VALUE zjournal_entry_create_request8(
                                        "利润中心
                                       profit_center = ls_zztfi_0001-prctr
                                           ).
            APPEND ls_gl TO lt_gl.
          ENDIF.
          "行项目----------END----------


          "整理发送数据
          ls_journalentry-message_header-creation_date_time = ls_tmp-local_last_changed_at.
          ls_journalentry-journal_entry-item = lt_gl.
          ls_journalentry-journal_entry-debtor_item = lt_debtor.

          "创建日期时间
          ls_request-journal_entry_bulk_create_requ-message_header-creation_date_time = ls_ztfi005-local_last_changed_at.

          APPEND ls_journalentry TO ls_request-journal_entry_bulk_create_requ-journal_entry_create_request.

          proxy->journal_entry_create_request_c(
            EXPORTING
              input = ls_request
            IMPORTING
              output = ls_response
          ).
          CLEAR:lv_text.
          DATA(ls_doc)  = ls_response-journal_entry_bulk_create_conf-journal_entry_create_confirmat[ 1 ]-journal_entry_create_confirmat.
          IF ls_doc-accounting_document <> '0000000000'.
            lv_severity = if_bali_constants=>c_severity_status.
            lv_text = |交易流水{ ls_ztfi005-transactionserialnumber }成功创建凭证{ ls_doc-accounting_document }|.
          ELSE.
            lv_severity = if_bali_constants=>c_severity_error.
            DATA(lt_log) = ls_response-journal_entry_bulk_create_conf-journal_entry_create_confirmat[ 1 ]-log-item.
            LOOP AT lt_log INTO DATA(ls_log).
              lv_text = lv_text && ls_log-note.
            ENDLOOP.
            lv_text = |交易流水{ ls_ztfi005-transactionserialnumber }凭证创建失败:{ lv_text }|.

          ENDIF.
          l_log->add_item( item = cl_bali_free_text_setter=>create(
            severity = lv_severity
            text = CONV #( lv_text ) ) ).

          "写入底表
          LOOP AT lt_md ASSIGNING FIELD-SYMBOL(<fs_md>).
            <fs_md>-msgty = lv_severity.
            <fs_md>-msgtx = lv_text.
            <fs_md>-local_last_changed_at = ls_tmp-local_last_changed_at.
          ENDLOOP.
          APPEND LINES OF lt_md TO lt_mdall.


        ENDLOOP.

        IF lt_mdall IS NOT INITIAL.
          MODIFY zztfi_0005 FROM TABLE @lt_mdall.
        ENDIF.

        cl_bali_log_db=>get_instance( )->save_log_2nd_db_connection( log = l_log
                                                           assign_to_current_appl_job = abap_true ).
      CATCH cx_bali_runtime INTO DATA(l_runtime_exception).
        IF 1 = 1.
        ENDIF.
      CATCH cx_soap_destination_error.
        IF 1 = 1.
        ENDIF.
      CATCH cx_ai_system_fault.
        IF 1 = 1.
        ENDIF.
    ENDTRY.





  ENDMETHOD.
ENDCLASS.
