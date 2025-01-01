FUNCTION zzfm_fi_003.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(I_REQ) TYPE  ZZS_FII003_REQ OPTIONAL
*"  EXPORTING
*"     REFERENCE(O_RESP) TYPE  ZZS_REST_OUT
*"----------------------------------------------------------------------

  DATA:lt_zztfi_0005 TYPE TABLE OF zztfi_0005,
       ls_zztfi_0005 TYPE zztfi_0005.

  DATA:lv_zztstmpl TYPE tzntstmpl.
  GET TIME STAMP FIELD lv_zztstmpl.

  LOOP AT i_req-req INTO DATA(ls_data).
    MOVE-CORRESPONDING ls_data TO ls_zztfi_0005.
    ls_zztfi_0005-zztstmpl = lv_zztstmpl.

    TRY .
        ls_zztfi_0005-uuid = cl_system_uuid=>if_system_uuid_static~create_uuid_x16( ).
      CATCH cx_uuid_error.
        IF 1 = 1.
        ENDIF.
    ENDTRY.

    APPEND ls_zztfi_0005 TO lt_zztfi_0005.
  ENDLOOP.

  "删除已经存储数据
*  SELECT transactionserialnumber
*    FROM zztfi_0005
*     FOR ALL ENTRIES IN @lt_zztfi_0005
*   WHERE transactionserialnumber = @lt_zztfi_0005-transactionserialnumber
*   INTO TABLE @DATA(lt_tmp).
*  SORT lt_tmp BY transactionserialnumber.
*  LOOP AT lt_zztfi_0005 INTO ls_zztfi_0005.
*    READ TABLE lt_tmp TRANSPORTING NO FIELDS WITH KEY transactionserialnumber = ls_zztfi_0005-transactionserialnumber BINARY SEARCH.
*    IF sy-subrc = 0.
*      DELETE lt_zztfi_0005.
*    ENDIF.
*  ENDLOOP.

  IF lt_zztfi_0005 IS NOT INITIAL.
    MODIFY zztfi_0005 FROM TABLE @lt_zztfi_0005.
  ENDIF.
*  "后台JOB处理
*  DATA job_template_name TYPE cl_apj_rt_api=>ty_template_name VALUE 'ZZ_JT_FI002'.
*  DATA job_start_info TYPE cl_apj_rt_api=>ty_start_info.
*  DATA job_parameters TYPE cl_apj_rt_api=>tt_job_parameter_value.
*  DATA job_name TYPE cl_apj_rt_api=>ty_jobname.
*  DATA job_count TYPE cl_apj_rt_api=>ty_jobcount.
*  DATA p_tstmpl TYPE c LENGTH 50.
*
*  p_tstmpl = lv_zztstmpl.
*  CONDENSE p_tstmpl NO-GAPS.
*
*  job_parameters = VALUE #( ( name  = 'TSTMPL'
*                              t_value = VALUE #( ( sign = 'I' option = 'EQ'  low = p_tstmpl ) ) ) ).
*
*  TRY.
*      cl_apj_rt_api=>schedule_job(
*            EXPORTING
*            iv_job_template_name = job_template_name
*            iv_job_text = |收款凭证创建 { lv_zztstmpl }|
*            is_start_info = job_start_info
*            it_job_parameter_value = job_parameters
*            IMPORTING
*            ev_jobname  = job_name
*            ev_jobcount = job_count
*            ).
*
*    CATCH cx_apj_rt INTO DATA(job_scheduling_error).
*      DATA(lv_text) = job_scheduling_error->get_longtext( ).
*  ENDTRY.

  o_resp-msgty = 'S'.
  o_resp-msgtx = '数据接收成功'.

ENDFUNCTION.
