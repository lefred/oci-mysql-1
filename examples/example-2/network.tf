############################################
# Create VCN
############################################
resource "oci_core_virtual_network" "MysqlVCN" {
  cidr_block     = "${lookup(var.network_cidrs, "VCN-CIDR")}"
  compartment_id = "${var.compartment_ocid}"
  display_name   = "MysqlVCN"
  dns_label      = "ocimysql"
}

############################################
# Create Internet Gateways
############################################
resource "oci_core_internet_gateway" "MysqlIG" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "${var.label_prefix}MysqlIG"
  vcn_id         = "${oci_core_virtual_network.MysqlVCN.id}"
}

############################################
# Create Route Table
############################################
resource "oci_core_route_table" "MysqlRT" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.MysqlVCN.id}"
  display_name   = "${var.label_prefix}MysqlRouteTable"

  route_rules {
    cidr_block = "0.0.0.0/0"

    # Internet Gateway route target for instances on public subnets
    network_entity_id = "${oci_core_internet_gateway.MysqlIG.id}"
  }
}

############################################
# Create Security List
############################################
resource "oci_core_security_list" "MysqlMasterSubnet" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "${var.label_prefix}MysqlSecurityList"
  vcn_id         = "${oci_core_virtual_network.MysqlVCN.id}"

  egress_security_rules = [{
    destination = "0.0.0.0/0"
    protocol    = "all"
  }]

  ingress_security_rules = [{
    tcp_options {
      "max" = 22
      "min" = 22
    }

    protocol = "6"
    source   = "0.0.0.0/0"
  },
    {
      tcp_options {
        "max" = "${var.http_port}"
        "min" = "${var.http_port}"
      }

      protocol = "6"
      source   = "0.0.0.0/0"
    },
  ]
}

############################################
# Create Master Subnet
############################################
resource "oci_core_subnet" "MysqlMasterSubnetAD" {
  availability_domain = "${data.template_file.ad_names.*.rendered[0]}"
  cidr_block          = "${lookup(var.network_cidrs, "masterSubnetAD")}"
  display_name        = "${var.label_prefix}MysqlMasterSubnetAD"
  dns_label           = "masterad"
  security_list_ids   = ["${oci_core_security_list.MysqlMasterSubnet.id}"]
  compartment_id      = "${var.compartment_ocid}"
  vcn_id              = "${oci_core_virtual_network.MysqlVCN.id}"
  route_table_id      = "${oci_core_route_table.MysqlRT.id}"
  dhcp_options_id     = "${oci_core_virtual_network.MysqlVCN.default_dhcp_options_id}"
}

############################################
# Create Slave Subnet
############################################
resource "oci_core_subnet" "MysqlSlaveSubnetAD" {
  count               = "${length(data.template_file.ad_names.*.rendered)}"
  availability_domain = "${data.template_file.ad_names.*.rendered[count.index]}"
  cidr_block          = "${lookup(var.network_cidrs, "slaveSubnetAD${count.index+1}")}"
  display_name        = "${var.label_prefix}MysqlSlaveSubnetAD${count.index+1}"
  dns_label           = "slavead${count.index+1}"
  security_list_ids   = ["${oci_core_virtual_network.MysqlVCN.default_security_list_id}"]
  compartment_id      = "${var.compartment_ocid}"
  vcn_id              = "${oci_core_virtual_network.MysqlVCN.id}"
  route_table_id      = "${oci_core_route_table.MysqlRT.id}"
  dhcp_options_id     = "${oci_core_virtual_network.MysqlVCN.default_dhcp_options_id}"
}