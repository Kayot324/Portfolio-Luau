export type Eventoyte = {
	Changed:  RBXScriptSignal;
	insert:  (value: any) -> ();
	k: (name: string, value: any) -> (), key: (name: string, value: any) -> (),
	remove:  (index: number) -> any;
	clear:   () -> ();
	Destroy: () -> ();
};

export type Historyoyte = {
	redo: () -> (), r: () -> (),
	undo: () -> (), u: () -> (),
};

return nil; --// wooow
