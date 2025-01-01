CLASS zzcl_idcn_acc_doc_cs_cloud DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_badi_interface .
    INTERFACES if_idcn_acc_doc_cs_cloud .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZZCL_IDCN_ACC_DOC_CS_CLOUD IMPLEMENTATION.


  METHOD if_idcn_acc_doc_cs_cloud~post_selection_control.
    DATA(lt_header_content) = it_header_content[].

    SELECT a~companycode,
           a~fiscalyear,
           a~accountingdocument,
           a~ledgergllineitem,
           c~fixedassetdescription,
           d~productname
     FROM i_journalentryitem WITH PRIVILEGED ACCESS AS a
     JOIN @lt_header_content AS b ON a~companycode        = b~bukrs
                                 AND a~fiscalyear         = b~gjahr
                                 AND a~accountingdocument = b~belnr
       LEFT JOIN i_fixedasset WITH PRIVILEGED ACCESS  AS c ON a~companycode = c~companycode                                                        AND a~masterfixedasset = c~masterfixedasset
                                                          AND a~fixedasset = c~fixedasset
      LEFT JOIN i_producttext WITH PRIVILEGED ACCESS  AS d ON a~product = d~product
                                                           AND d~language = @sy-langu
   WHERE a~sourceledger = '0L'
    INTO TABLE @DATA(lt_data).

    LOOP AT ct_line_content ASSIGNING FIELD-SYMBOL(<fs_content>).
      READ TABLE lt_data INTO DATA(ls_data) WITH KEY companycode = <fs_content>-bukrs
                                                     accountingdocument = <fs_content>-belnr
                                                     fiscalyear = <fs_content>-gjahr
                                                     ledgergllineitem+3(3) = <fs_content>-buzei.
      IF sy-subrc = 0.
        <fs_content>-custom_field1 = ls_data-fixedassetdescription.
        <fs_content>-custom_field2 = ls_data-productname.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
