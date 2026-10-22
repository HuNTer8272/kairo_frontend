import 'package:flutter/widgets.dart';

import '../../services/apollo/apollo_service.dart';

/// Rebuilds [builder] only when [selector]'s result changes (by `==`).
///
/// The Apollo state updates up to 10 times a second while the car moves;
/// most widgets show a few fields that change far less often (a gear, a
/// lock, a rounded speed). Selecting those as a record keeps rebuilds to
/// the moments something visible actually changed.
class ApolloSelector<T> extends StatefulWidget {
  const ApolloSelector({
    super.key,
    required this.apollo,
    required this.selector,
    required this.builder,
  });

  final ApolloService apollo;
  final T Function(ApolloService apollo) selector;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<ApolloSelector<T>> createState() => _ApolloSelectorState<T>();
}

class _ApolloSelectorState<T> extends State<ApolloSelector<T>> {
  late T _value = widget.selector(widget.apollo);

  @override
  void initState() {
    super.initState();
    widget.apollo.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(ApolloSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.apollo, widget.apollo)) {
      oldWidget.apollo.removeListener(_onChanged);
      widget.apollo.addListener(_onChanged);
    }
    _value = widget.selector(widget.apollo);
  }

  @override
  void dispose() {
    widget.apollo.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final next = widget.selector(widget.apollo);
    if (next != _value) setState(() => _value = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
