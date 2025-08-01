import 'package:equatable/equatable.dart';

class ChaturajiMove extends Equatable {
  final int from;
  final int to;

  const ChaturajiMove(this.from, this.to);

  @override
  // List all properties that should be considered for equality.
  List<Object?> get props => [from, to];
}
