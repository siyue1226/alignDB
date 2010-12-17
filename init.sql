/*==============================================================*/
/* DBMS name:      MySQL 4.0                                    */
/* Created on:     2008/12/15 1:57:48                           */
/*==============================================================*/

/*==============================================================*/
/* Table: align                                                 */
/*==============================================================*/
create table align
(
   align_id                       int                            not null AUTO_INCREMENT,
   tvsq_id                        int,
   align_length                   int,
   comparable_bases               int,
   identities                     int,
   differences                    int,
   gaps                           int,
   ns                             int,
   align_error                    int,
   pi                             double,
   target_gc_ratio                double,
   query_gc_ratio                 double,
   comparable_runlist             text,
   indel_runlist                  text,
   primary key (align_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: tvsq_align_FK                                         */
/*==============================================================*/
create index tvsq_align_FK on align
(
   tvsq_id
);

/*==============================================================*/
/* Table: align_extra                                           */
/*==============================================================*/
create table align_extra
(
   align_extra_id                 int                            not null AUTO_INCREMENT,
   align_id                       int,
   align_feature1                 double,
   align_feature2                 double,
   align_feature3                 double,
   align_feature4                 double,
   align_feature5                 text,
   align_feature6                 text,
   align_feature7                 text,
   align_feature8                 text,
   primary key (align_extra_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: align_align_extra_FK                                  */
/*==============================================================*/
create index align_align_extra_FK on align_extra
(
   align_id
);

/*==============================================================*/
/* Table: chromosome                                            */
/*==============================================================*/
create table chromosome
(
   chr_id                         int                            not null AUTO_INCREMENT,
   taxon_id                       int,
   chr_name                       text,
   chr_length                     int,
   primary key (chr_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: taxon_chromosome_FK                                   */
/*==============================================================*/
create index taxon_chromosome_FK on chromosome
(
   taxon_id
);

/*==============================================================*/
/* Table: codingsw                                              */
/*==============================================================*/
create table codingsw
(
   codingsw_id                    int                            not null AUTO_INCREMENT,
   exon_id                        int,
   foregoing_exon_id              int,
   window_id                      int,
   codingsw_type                  char(1),
   codingsw_distance              int,
   primary key (codingsw_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: exon_codingsw_FK                                      */
/*==============================================================*/
create index exon_codingsw_FK on codingsw
(
   exon_id,
   foregoing_exon_id
);

/*==============================================================*/
/* Index: window_codingsw_FK                                    */
/*==============================================================*/
create index window_codingsw_FK on codingsw
(
   window_id
);

/*==============================================================*/
/* Table: exon                                                  */
/*==============================================================*/
create table exon
(
   exon_id                        int                            not null AUTO_INCREMENT,
   foregoing_exon_id              int                            not null,
   window_id                      int,
   gene_id                        int,
   exon_stable_id                 char(64)                       not null,
   exon_strand                    char(1),
   exon_phase                     int,
   exon_end_phase                 int,
   exon_frame                     int,
   exon_rank                      int,
   exon_is_full                   int,
   exon_tl_start                  int,
   exon_tl_end                    int,
   exon_tl_runlist                text,
   exon_seq                       longtext,
   exon_peptide                   longtext,
   primary key (exon_id, foregoing_exon_id),
   key AK_exon_stable_id (exon_stable_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: window_exon_FK                                        */
/*==============================================================*/
create index window_exon_FK on exon
(
   window_id
);

/*==============================================================*/
/* Index: gene_exon_FK                                          */
/*==============================================================*/
create index gene_exon_FK on exon
(
   gene_id
);

/*==============================================================*/
/* Table: exonsw                                                */
/*==============================================================*/
create table exonsw
(
   exonsw_id                      int                            not null AUTO_INCREMENT,
   window_id                      int,
   exon_id                        int,
   foregoing_exon_id              int,
   exonsw_type                    char(1),
   exonsw_distance                int,
   exonsw_density                 int,
   primary key (exonsw_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: exon_exonsw_FK                                        */
/*==============================================================*/
create index exon_exonsw_FK on exonsw
(
   exon_id,
   foregoing_exon_id
);

/*==============================================================*/
/* Index: window_exonsw_FK                                      */
/*==============================================================*/
create index window_exonsw_FK on exonsw
(
   window_id
);

/*==============================================================*/
/* Table: extreme                                               */
/*==============================================================*/
create table extreme
(
   extreme_id                     int                            not null AUTO_INCREMENT,
   foregoing_extreme_id           int                            not null,
   window_id                      int,
   extreme_type                   char(1),
   extreme_left_amplitude         double,
   extreme_right_amplitude        double,
   extreme_left_wave_length       double,
   extreme_right_wave_length      double,
   primary key (extreme_id, foregoing_extreme_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: windows_extreme_FK                                    */
/*==============================================================*/
create index windows_extreme_FK on extreme
(
   window_id
);

/*==============================================================*/
/* Table: gene                                                  */
/*==============================================================*/
create table gene
(
   gene_id                        int                            not null AUTO_INCREMENT,
   window_id                      int,
   gene_stable_id                 char(64)                       not null,
   gene_external_name             char(64),
   gene_biotype                   char(64),
   gene_strand                    char(1),
   gene_is_full                   int,
   gene_is_known                  int,
   gene_multitrans                int,
   gene_multiexons                int,
   gene_tc_start                  int,
   gene_tc_end                    int,
   gene_tc_runlist                text,
   gene_tl_start                  int,
   gene_tl_end                    int,
   gene_tl_runlist                text,
   gene_description               text,
   gene_go                        char(64),
   gene_feature4                  double,
   gene_feature5                  double,
   primary key (gene_id),
   key AK_gene_stable_id (gene_stable_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: window_gene_FK                                        */
/*==============================================================*/
create index window_gene_FK on gene
(
   window_id
);

/*==============================================================*/
/* Table: genesw                                                */
/*==============================================================*/
create table genesw
(
   genesw_id                      int                            not null AUTO_INCREMENT,
   window_id                      int,
   gene_id                        int,
   genesw_type                    char(1),
   genesw_distance                int,
   primary key (genesw_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: gene_genesw_FK                                        */
/*==============================================================*/
create index gene_genesw_FK on genesw
(
   gene_id
);

/*==============================================================*/
/* Index: window_genesw_FK                                      */
/*==============================================================*/
create index window_genesw_FK on genesw
(
   window_id
);

/*==============================================================*/
/* Table: gsw                                                   */
/*==============================================================*/
create table gsw
(
   gsw_id                         int                            not null AUTO_INCREMENT,
   extreme_id                     int,
   foregoing_extreme_id           int,
   window_id                      int,
   gsw_type                       char(1),
   gsw_distance                   int,
   gsw_density                    int,
   gsw_amplitude                  int,
   primary key (gsw_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: windows_gsw_FK                                        */
/*==============================================================*/
create index windows_gsw_FK on gsw
(
   window_id
);

/*==============================================================*/
/* Index: extreme_gsw_FK                                        */
/*==============================================================*/
create index extreme_gsw_FK on gsw
(
   extreme_id,
   foregoing_extreme_id
);

/*==============================================================*/
/* Table: indel                                                 */
/*==============================================================*/
create table indel
(
   indel_id                       int                            not null AUTO_INCREMENT,
   foregoing_indel_id             int                            not null,
   align_id                       int,
   indel_start                    int,
   indel_end                      int,
   indel_length                   int,
   indel_seq                      longtext,
   indel_insert                   char(1),
   left_extand                    int,
   right_extand                   int,
   indel_gc_ratio                 double,
   indel_dG                       double,
   indel_occured                  char(1),
   indel_type                     char(1),
   primary key (indel_id, foregoing_indel_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: align_indel_FK                                        */
/*==============================================================*/
create index align_indel_FK on indel
(
   align_id
);

/*==============================================================*/
/* Table: indel_extra                                           */
/*==============================================================*/
create table indel_extra
(
   indel_extra_id                 int                            not null AUTO_INCREMENT,
   indel_id                       int,
   foregoing_indel_id             int,
   indel_feature1                 double,
   indel_feature2                 double,
   indel_feature3                 double,
   primary key (indel_extra_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: indel_indel_extra_FK                                  */
/*==============================================================*/
create index indel_indel_extra_FK on indel_extra
(
   indel_id,
   foregoing_indel_id
);

/*==============================================================*/
/* Table: isw                                                   */
/*==============================================================*/
create table isw
(
   isw_id                         int                            not null AUTO_INCREMENT,
   indel_id                       int,
   foregoing_indel_id             int,
   isw_start                      int,
   isw_end                        int,
   isw_length                     int,
   isw_type                       char(1),
   isw_distance                   int,
   isw_density                    int,
   isw_pi                         double,
   isw_target_gc_ratio            double,
   isw_query_gc_ratio             double,
   isw_target_dG                  double,
   isw_query_dG                   double,
   isw_d_indel                    double,
   isw_d_noindel                  double,
   isw_d_complex                  double,
   primary key (isw_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: indel_isw_FK                                          */
/*==============================================================*/
create index indel_isw_FK on isw
(
   indel_id,
   foregoing_indel_id
);

/*==============================================================*/
/* Table: isw_extra                                             */
/*==============================================================*/
create table isw_extra
(
   isw_extra_id                   int                            not null AUTO_INCREMENT,
   isw_id                         int,
   isw_feature1                   double,
   isw_feature2                   double,
   isw_feature3                   double,
   primary key (isw_extra_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: isw_isw_extra_FK                                      */
/*==============================================================*/
create index isw_isw_extra_FK on isw_extra
(
   isw_id
);

/*==============================================================*/
/* Table: meta                                                  */
/*==============================================================*/
create table meta
(
   meta_id                        int                            not null AUTO_INCREMENT,
   meta_key                       text,
   meta_value                     text,
   primary key (meta_id)
)
type = MyISAM;

/*==============================================================*/
/* Table: ofg                                                   */
/*==============================================================*/
create table ofg
(
   ofg_id                         int                            not null AUTO_INCREMENT,
   window_id                      int,
   ofg_tag                        char(64),
   ofg_type                       char(64),
   primary key (ofg_id)
)
comment = "Other feature of genome"
type = MyISAM;

/*==============================================================*/
/* Index: window_ofg_FK                                         */
/*==============================================================*/
create index window_ofg_FK on ofg
(
   window_id
);

/*==============================================================*/
/* Table: ofgsw                                                 */
/*==============================================================*/
create table ofgsw
(
   ofgsw_id                       int                            not null AUTO_INCREMENT,
   ofg_id                         int,
   window_id                      int,
   ofgsw_type                     char(1),
   ofgsw_distance                 int,
   primary key (ofgsw_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: ofg_ofgsw_FK                                          */
/*==============================================================*/
create index ofg_ofgsw_FK on ofgsw
(
   ofg_id
);

/*==============================================================*/
/* Index: window_ofgsw_FK                                       */
/*==============================================================*/
create index window_ofgsw_FK on ofgsw
(
   window_id
);

/*==============================================================*/
/* Table: query                                                 */
/*==============================================================*/
create table query
(
   query_id                       int                            not null AUTO_INCREMENT,
   seq_id                         int,
   align_id                       int,
   query_seq                      longtext,
   query_strand                   char(1),
   query_runlist                  text,
   primary key (query_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: sequence_query_FK                                     */
/*==============================================================*/
create index sequence_query_FK on query
(
   seq_id
);

/*==============================================================*/
/* Index: align_query_FK                                        */
/*==============================================================*/
create index align_query_FK on query
(
   align_id
);

/*==============================================================*/
/* Table: reference                                             */
/*==============================================================*/
create table reference
(
   ref_id                         int                            not null AUTO_INCREMENT,
   align_id                       int,
   ref_seq                        longtext,
   ref_raw_seq                    longtext,
   ref_complex_indel              text,
   primary key (ref_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: align_reference_FK                                    */
/*==============================================================*/
create index align_reference_FK on reference
(
   align_id
);

/*==============================================================*/
/* Table: segment                                               */
/*==============================================================*/
create table segment
(
   segment_id                     int                            not null AUTO_INCREMENT,
   window_id                      int,
   segment_type                   char(1),
   segment_gc_mean                double,
   segment_gc_std                 double,
   segment_gc_cv                  double,
   segment_gc_mdcw                double,
   primary key (segment_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: window_segment_FK                                     */
/*==============================================================*/
create index window_segment_FK on segment
(
   window_id
);

/*==============================================================*/
/* Table: sequence                                              */
/*==============================================================*/
create table sequence
(
   seq_id                         int                            not null AUTO_INCREMENT,
   chr_id                         int,
   chr_start                      int,
   chr_end                        int,
   chr_strand                     char(1),
   seq_length                     int,
   primary key (seq_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: chromosome_sequence_FK                                */
/*==============================================================*/
create index chromosome_sequence_FK on sequence
(
   chr_id
);

/*==============================================================*/
/* Table: snp                                                   */
/*==============================================================*/
create table snp
(
   snp_id                         int                            not null AUTO_INCREMENT,
   isw_id                         int,
   align_id                       int,
   snp_pos                        int,
   target_base                    char(1),
   query_base                     char(1),
   ref_base                       char(1),
   snp_occured                    char(1),
   primary key (snp_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: align_snp_FK                                          */
/*==============================================================*/
create index align_snp_FK on snp
(
   align_id
);

/*==============================================================*/
/* Index: isw_snp_FK                                            */
/*==============================================================*/
create index isw_snp_FK on snp
(
   isw_id
);

/*==============================================================*/
/* Table: snp_extra                                             */
/*==============================================================*/
create table snp_extra
(
   snp_extra_id                   int                            not null AUTO_INCREMENT,
   snp_id                         int,
   snp_feature1                   double,
   snp_feature2                   double,
   snp_feature3                   double,
   primary key (snp_extra_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: snp_snp_extra_FK                                      */
/*==============================================================*/
create index snp_snp_extra_FK on snp_extra
(
   snp_id
);

/*==============================================================*/
/* Table: ssw                                                   */
/*==============================================================*/
create table ssw
(
   ssw_id                         int                            not null AUTO_INCREMENT,
   snp_id                         int,
   window_id                      int,
   ssw_type                       char(1),
   ssw_distance                   int,
   ssw_d_snp                      double,
   ssw_d_nosnp                    double,
   ssw_d_complex                  double,
   primary key (ssw_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: window_ssw_FK                                         */
/*==============================================================*/
create index window_ssw_FK on ssw
(
   window_id
);

/*==============================================================*/
/* Index: snp_ssw_FK                                            */
/*==============================================================*/
create index snp_ssw_FK on ssw
(
   snp_id
);

/*==============================================================*/
/* Table: target                                                */
/*==============================================================*/
create table target
(
   target_id                      int                            not null AUTO_INCREMENT,
   align_id                       int,
   seq_id                         int,
   target_seq                     longtext,
   target_runlist                 text,
   primary key (target_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: sequence_target_FK                                    */
/*==============================================================*/
create index sequence_target_FK on target
(
   seq_id
);

/*==============================================================*/
/* Index: align_target_FK                                       */
/*==============================================================*/
create index align_target_FK on target
(
   align_id
);

/*==============================================================*/
/* Table: taxon                                                 */
/*==============================================================*/
create table taxon
(
   taxon_id                       int                            not null AUTO_INCREMENT,
   genus                          text,
   species                        text,
   sub_species                    text,
   common_name                    text,
   classification                 text,
   primary key (taxon_id)
)
type = MyISAM;

/*==============================================================*/
/* Table: tvsq                                                  */
/*==============================================================*/
create table tvsq
(
   tvsq_id                        int                            not null AUTO_INCREMENT,
   target_taxon_id                int,
   target_name                    text,
   query_taxon_id                 int,
   query_name                     text,
   ref_taxon_id                   int,
   ref_name                       text,
   primary key (tvsq_id)
)
type = MyISAM;

/*==============================================================*/
/* Table: window                                                */
/*==============================================================*/
create table window
(
   window_id                      int                            not null AUTO_INCREMENT,
   align_id                       int,
   window_start                   int,
   window_end                     int,
   window_length                  int,
   window_runlist                 text,
   window_comparables             int,
   window_identities              int,
   window_differences             int,
   window_indel                   int,
   window_pi                      double,
   window_target_gc               double,
   window_query_gc                double,
   window_target_dG               double,
   window_query_dG                double,
   window_feature1                double,
   window_feature2                double,
   window_feature3                double,
   primary key (window_id)
)
type = MyISAM;

/*==============================================================*/
/* Index: align_window_FK                                       */
/*==============================================================*/
create index align_window_FK on window
(
   align_id
);
