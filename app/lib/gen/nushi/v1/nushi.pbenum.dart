// This is a generated file - do not edit.
//
// Generated from nushi/v1/nushi.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ItemKind extends $pb.ProtobufEnum {
  static const ItemKind ITEM_KIND_UNSPECIFIED =
      ItemKind._(0, _omitEnumNames ? '' : 'ITEM_KIND_UNSPECIFIED');
  static const ItemKind ITEM_KIND_USER_MESSAGE =
      ItemKind._(1, _omitEnumNames ? '' : 'ITEM_KIND_USER_MESSAGE');
  static const ItemKind ITEM_KIND_AGENT_MESSAGE =
      ItemKind._(2, _omitEnumNames ? '' : 'ITEM_KIND_AGENT_MESSAGE');

  static const $core.List<ItemKind> values = <ItemKind>[
    ITEM_KIND_UNSPECIFIED,
    ITEM_KIND_USER_MESSAGE,
    ITEM_KIND_AGENT_MESSAGE,
  ];

  static final $core.List<ItemKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ItemKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ItemKind._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
